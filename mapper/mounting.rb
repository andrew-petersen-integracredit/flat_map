module Core
  module FlatMap
    module Mapper::Mounting
      extend ActiveSupport::Concern

      module ClassMethods
        def mount(*args)
          mountings << FlatMap::Mapper::Factory.new(*args)
        end

        def mountings
          @mountings ||= []
        end
      end

      def read
        mountings.inject(super) do |result, mapper|
          result.merge(mapper.read)
        end
      end

      def write(params)
        super

        mountings.each do |mapper|
          mapper.write(params)
        end

        params
      end

      # Overloaded by {Traits}
      def mountings
        @mountings ||= self.class.mountings.map{ |factory| factory.create(self) }
      end
      private :mountings
    end
  end
end
