module Core
  module FlatMap
    # This small module allows mappers to define traits, which technically
    # means mounting anonymous mappers, attached to host one.
    #
    # Also, Core::FlatMap::Mapper::Mounting#mountings completely overridden
    # here to support special trait behavior.
    module Mapper::Traits
      extend ActiveSupport::Concern

      # Traits class macros
      module ClassMethods
        # Defines a trait for a mapper class. A trait in terms of implementation is nothing
        # more than a mounted mapper, owned by host mapper. It shares all mappings with it.
        # The block is passed as a body of the anonymous mapper class.
        #
        # @param [Symbol] name
        def trait(name, &block)
          mapper_class = Class.new(Core::FlatMap::Mapper, &block)
          # validations require class.name to be set
          mapper_class_name = "#{self.name}#{name.to_s.camelize}Trait"
          mapper_class.singleton_class.send(:define_method, :name){ mapper_class_name }
          mount mapper_class, :trait_name => name
        end
      end

      # Override original {Core::FlatMap::Mapper::Mounting#mountings} method to filter
      # out those traited mappers that are not required for trait setup of +self+
      #
      # @return [Array<Core::FlatMap::Mapper>]
      def mountings
        @mountings ||= begin
          mountings = self.class.mountings.reject{ |factory| factory.traited? && !factory.required_for_any_trait?(traits) }
          mountings.map{ |factory| factory.create(self, *traits) }
        end
      end
      private :mountings
    end
  end
end
