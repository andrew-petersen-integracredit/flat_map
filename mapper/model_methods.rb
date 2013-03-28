module Core
  module FlatMap
    # This module provides some integration between mapper and its target,
    # which is usually an ActiveRecord model, as well as some integration
    # between mapper and Rails forms.
    #
    # In particular, validation and save methods are defined here. And
    # the <tt>save</tt> method itself is defined as a callback. Also, Rails
    # multiparam attributes extraction is defined within this module.
    module Mapper::ModelMethods
      extend ActiveSupport::Concern

      included do
        define_callbacks :save

        # Writer of the target class name. Allows manual control over target
        # class of the mapper, for example:
        #
        #   class CustomerMapper
        #     self.target_class_name = 'Customer::Active'
        #   end
        class_attribute :target_class_name
      end

      # ModelMethods class macros
      module ClassMethods
        # Create a new mapper object wrapped around new instance of its
        # +target_class+, with a list of passed +traits+ applied to it.
        #
        # @param [*Symbol] traits
        # @return [Core::FlatMap::Mapper] mapper
        def build(*traits, &block)
          new(target_class.new, *traits, &block)
        end

        # Find a record of the +target_class+ by +id+ and use it as a
        # target for a new mapper, with a list of passed +traits+ applied
        # to it.
        #
        # @param [#to_i] id of the record
        # @param [*Symbol] traits
        # @return [Core::FlatMap::Mapper] mapper
        def find(id, *traits, &block)
          new(target_class.find(id), *traits, &block)
        end

        # Fetch a class for the target of the mapper.
        #
        # @return [Class] class
        def target_class
          (target_class_name || default_target_class_name).constantize
        end

        # Return target class name based on name of the ancestor mapper
        # that is closest to {Core::FlatMap::Mapper}, which may be +self+.
        #
        #   class VehicleMapper
        #     # some definitions
        #   end
        #
        #   class CarMapper < VehicleMapper
        #     # some more definitions
        #   end
        #
        #   CarMapper.target_class # => Vehicle
        #
        # @return [String]
        def default_target_class_name
          core_mapper_index = ancestors.index(::Core::FlatMap::Mapper)
          ancestors[core_mapper_index - 1].name[/^(\w+)Mapper.*$/, 1]
        end
      end

      # Return a 'mapper' string as a model_name. Used by Rails FormBuilder.
      #
      # @return [String]
      def model_name
        'mapper'
      end

      # Delegate to the target's #to_key method.
      # @return [String]
      def to_key
        target.to_key
      end

      # Write a passed set of +params+. Then try to save the model if +self+
      # passes validation. Saving is performed in a transaction.
      #
      # @param [Hash] params
      # @return [Boolean]
      def apply(params)
        write(params)
        res = if valid?
          ActiveRecord::Base.transaction do
            save
          end
        end
        !!res
      end

      # Extract the multiparam values from the passed +params+. Then use the
      # resulting hash to assign values to the target. Assignment is performed
      # by sending writer methods to +self+ that correspond to keys in the
      # resulting +params+ hash.
      #
      # @param [Hash] params
      # @return [Hash] params
      def write(params)
        extract_multiparams!(params)

        params.each do |name, value|
          self.send("#{name}=", value)
        end
      end

      # Try to save the target and send a +save+ method to all mounted mappers.
      #
      # The order in which mappings are saved is important, since we save
      # records with :validate => false option. Since Rails will perform
      # auto-saving on associations (and it in its turn will try to save associated
      # record with :validate => true option. To be more precise, with
      # :validate => !autosave option, where autosave corresponds to that option
      # of reflection, which is usually not specified, i.e. nil), we might come to
      # a situation of saving a record with nil foreign key for belongs_to association,
      # which will raise exception. Thus, we want to explicitly save records in
      # order which will allow them to be saved.
      # Return +false+ if that chain of +save+ calls returns +true+ on any of
      # its elements. Return +true+ otherwise.
      #
      # Saving is performed as a callback.
      #
      # @return [Boolean]
      def save
        run_callbacks :save do
          before_res = save_mountings(before_save_mountings)
          target_res = self_mountings.map{ |m| m.shallow_save }.all?
          after_res  = save_mountings(after_save_mountings)

          before_res && target_res && after_res
        end
      end

      # Save +target+
      #
      # @return [Boolean]
      def save_target
        return true if owned?
        target.respond_to?(:save) ? target.save(:validate => false) : true
      end

      # Perform target save with callbacks call
      #
      # @return [Boolean]
      def shallow_save
        run_callbacks(:save){ save_target }
      end

      # Send <tt>:save</tt> method to all mountings in list. Will return +true+
      # only if all savings are positive.
      #
      # @param [Array<Core::FlatMap::Mapper>] mountings
      # @return [Boolean]
      def save_mountings(mountings)
        mountings.map{ |mount| mount.save }.all?
      end
      private :save_mountings

      # Return +true+ if the mapper is valid, i.e. if it is valid itself, and if
      # all mounted mappers (traits and other mappers) are also valid.
      #
      # @return [Boolean]
      def valid?
        res = trait_mountings.map(&:valid?).all?
        res = super && res # we do want to call super
        mounting_res = mapper_mountings.map(&:valid?).all?
        consolidate_errors!
        res && mounting_res
      end

      # Consolidate the errors of all mounted mappers to a set of errors of +self+.
      #
      # @return [Array<ActiveModel::Errors>]
      def consolidate_errors!
        mountings.map(&:errors).each do |errs|
          errors.messages.merge!(errs.to_hash){ |k, old, new| old.concat(new) }
        end
      end
      private :consolidate_errors!

      # Extract Rails multiparam parameters from the +params+, modifying
      # original hash. Behaves somewhat like
      # {ActiveRecord::AttributeAssignment#extract_callstack_for_multiparameter_attributes}
      # See this method for more details.
      #
      # @param [Hash] params
      # @return [Array<Core::FlatMap::Mapping>] return value is not used, original
      #   +params+ hash is modified instead and used later on.
      def extract_multiparams!(params)
        all_mappings.select(&:multiparam?).each do |mapping|
          param_keys = params.keys.
            select{ |k| k.to_s =~ /#{mapping.name}\(\d+[isf]\)/ }.
            sort_by{ |k| k.to_s[/\((\d+)\w*\)/, 1].to_i }

          next if param_keys.empty?

          args = param_keys.inject([]) do |values, key|
            value = params.delete key
            type  = key[/\(\d+(\w*)\)/, 1]
            value = value.send("to_#{type}") unless type.blank?

            values.push value
            values
          end

          params[mapping.name] = mapping.multiparam.new(*args) rescue nil
        end
      end
      private :extract_multiparams!
    end
  end
end
