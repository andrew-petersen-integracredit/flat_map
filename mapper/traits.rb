module Core
  module FlatMap
    module Mapper::Traits
      extend ActiveSupport::Concern

      module ClassMethods
        def trait(name, &block)
          mapper_class = Class.new(Core::FlatMap::Mapper, &block)
          # validations require class.name to be set
          mapper_class_name = "#{self.name}#{name.to_s.camelize}Trait"
          mapper_class.singleton_class.send(:define_method, :name){ mapper_class_name }
          mount mapper_class, :trait_name => name
        end
      end

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
