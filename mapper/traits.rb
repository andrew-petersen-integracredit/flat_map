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
        # Define a trait for a mapper class. In implementation terms, a trait
        # is nothing more than a mounted mapper, owned by a host mapper.
        # It shares all mappings with it.
        # The block is passed as a body of the anonymous mapper class.
        #
        # @param [Symbol] name
        def trait(name, &block)
          mapper_class = Class.new(Core::FlatMap::Mapper, &block)
          # validations require class.name to be set
          mapper_class_name = "#{self.name || ancestors.first.name}#{name.to_s.camelize}Trait"
          mapper_class.singleton_class.send(:define_method, :name){ mapper_class_name }
          mount mapper_class, :trait_name => name
        end
      end

      # Override the original {Core::FlatMap::Mapper::Mounting#mountings}
      # method to filter out those traited mappers that are not required for
      # trait setup of +self+. Also, handle any inline extension that may be
      # defined on the mounting mapper, which is attached as a singleton trait.
      #
      # @return [Array<Core::FlatMap::Mapper>]
      def mountings
        @mountings ||= begin
          mountings = self.class.mountings.
                                 reject{ |factory|
                                   factory.traited? &&
                                   !factory.required_for_any_trait?(traits)
                                 }
          mountings.concat(singleton_class.mountings)
          mountings.map{ |factory| factory.create(self, *traits) }
        end
      end

      # Return only mountings that are actually traits for host mapper.
      #
      # @return [Array<Core::FlatMap::Mapper>]
      def trait_mountings
        mountings.select{ |m| m.owned? }
      end
      protected :trait_mountings

      # Return only mountings that correspond to external mappers.
      #
      # @return [Array<Core::FlatMap::Mapper>]
      def mapper_mountings
        mountings.select{ |m| !m.owned? }
      end
      protected :mapper_mountings
    end
  end
end
