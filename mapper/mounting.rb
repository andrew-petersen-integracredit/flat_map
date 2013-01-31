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

      # def all_mountings
      #   mountings.dup.concat(mountings.map(&:all_mountings)).flatten
      # end
      # private :all_mountings

      def all_mappings
        return all_nested_mappings unless owned?
        owner.all_mappings
      end
      protected :all_mappings

      def all_nested_mappings
        (mappings + mountings.map(&:all_nested_mappings)).flatten
      end
      protected :all_nested_mappings
    end
  end
end
