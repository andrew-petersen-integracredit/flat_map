module FlatMap
  # This module enhances and modifies original FlatMap::OpenMapper::Persistence
  # functionality for ActiveRecord models as targets.
  module ModelMapper::Persistence
    extend ActiveSupport::Concern

    included do
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
      # Find a record of the +target_class+ by +id+ and use it as a
      # target for a new mapper, with a list of passed +traits+ applied
      # to it.
      #
      # @param [#to_i] id of the record
      # @param [*Symbol] traits
      # @return [FlatMap::Mapper] mapper
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
      # that is closest to {FlatMap::Mapper}, which may be +self+.
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
        ancestor_classes  = ancestors.select{ |ancestor| ancestor.is_a? Class }
        base_mapper_index = ancestor_classes.index(::FlatMap::ModelMapper)
        ancestor_classes[base_mapper_index - 1].name[/^([\w:]+)Mapper.*$/, 1]
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

    # Save +target+
    #
    # @return [Boolean]
    def save_target
      return true if owned?
      target.respond_to?(:save) ? target.save(:validate => false) : true
    end

    # Delegate persistence to target.
    #
    # @return [Boolean]
    def persisted?
      target.respond_to?(:persisted?) ? target.persisted? : false
    end

    # Delegate #id to target, if possible.
    #
    # @return [Fixnum, nil]
    def id
      target.id if target.respond_to?(:id)
    end
  end
end
