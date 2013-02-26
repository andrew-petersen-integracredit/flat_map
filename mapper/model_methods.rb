module Core
  module FlatMap
    # This module provides some integration between mapper and it's target,
    # which is usually an ActiveRecord model, as well as some integration
    # between mapper and Rails forms.
    #
    # In particular, validation and save methods are defined here. And
    # <tt>save</tt> method itself is defined as a callback. Also, Rails
    # multiparam attributes extraction is defined within this module.
    module Mapper::ModelMethods
      extend ActiveSupport::Concern

      included do
        define_callbacks :save
      end

      # ModelMethods class macros
      module ClassMethods
        # Creates a new mapper object wrapped around new instance of its
        # +target_class+, with a list of passed +traits+ applied to it
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

        # Fetch a class for the target of the mapper
        #
        # @return [Class] class
        def target_class
          target_class_name.constantize
        end

        # Writer of the target class name. Allows manual control over target
        # class of the mapper, for example:
        #
        #   class CustomerMapper
        #     self.target_class_name = 'Customer::Active'
        #   end
        #
        # @param [String] class_name
        # @return [String] class_name
        def target_class_name=(class_name)
          @target_class_name = class_name
        end

        # Return a name of the target class. Fetches it by name of the +self+
        # if it is undefined.
        #
        # @return [String] class_name
        def target_class_name
          @target_class_name ||= self.name[/^(\w+)Mapper.*$/, 1]
        end
      end

      # Return a 'mapper' string as a model_name. Used by Rails FormBuilder
      #
      # @return [String]
      def model_name
        'mapper'
      end

      # Delegate to target's #to_key method
      # @return [String]
      def to_key
        target.to_key
      end

      # Write a passed set of +params+, then try to save the model if +self+
      # passes validation. Saving is performed in a transaction
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

      # Extracts multiparam values from the passed +params+, then uses resulted
      # hash to assign values to target. Assignment is performed by sending
      # writer methods to +self+ that correspond to keys in resulted +params+ hash
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
      # Return +false+ if that chain of +save+ calls returns true on any of
      # it's elements. Return +true+ otherwise.
      #
      # Saving is performed as a callback.
      #
      # @return [Boolean]
      def save
        run_callbacks :save do
          res = true
          mountings.each do |mapper|
            break unless res
            res = mapper.save
          end
          unless owned?
            res = res && target.respond_to?(:save) ? target.save(:validate => false) : true
          end
          res
        end
      end

      # Return +true+ if mapper is valid, i.e. if it is valid itself, and if
      # all mounted mappers (traits and other mappers) are valid also
      #
      # @return [Boolean]
      def valid?
        res = trait_mountings.map(&:valid?).all?
        res = super && res # we do want to call super
        mounting_res = mapper_mountings.map(&:valid?).all?
        consolidate_errors!
        res && mounting_res
      end

      # Consolidate errors of all mounted mappers to a set of errors of +self+
      #
      # @return [Array<ActiveModel::Errors>]
      def consolidate_errors!
        mountings.map(&:errors).each do |errs|
          errors.messages.merge!(errs.to_hash){ |k, old, new| old.concat(new) }
        end
      end
      private :consolidate_errors!

      # Extract Rails multiparam parameters from the +params+, modifying
      # original hash. Behaves somewhat like #{ActiveRecord::AttributeAssignment#extract_callstack_for_multiparameter_attributes}
      # See this method for some details.
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
