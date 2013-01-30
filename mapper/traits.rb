module Core
  module FlatMap
    module Mapper::Traits
      extend ActiveSupport::Concern

      module ClassMethods
        def trait(name, &block)
          mapper_class = Class.new(Core::FlatMap::Mapper, &block)
          mount mapper_class, :trait => name
        end
      end

      def mountings
        @mountings ||= begin
          mountings = self.class.mountings.reject{ |factory| factory.traited? && !factory.required_for_any_trait?(traits) }
          mountings.map{ |factory| factory.create(self) }
        end
      end
    end
  end
end
