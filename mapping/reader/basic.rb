module Core
  module FlatMap
    module Mapping::Reader
      class Basic
        attr_reader :mapping

        delegate :target, :target_attribute, :to => :mapping

        # Initializes reader with mapping
        #
        # @param [Core::FlatMap::Mapping] mapping
        def initialize(mapping)
          @mapping = mapping
        end

        # Simply sends attribute method to the target and returns
        # its value
        #
        # @return [Object] value returned by reading
        def read
          target.send(target_attribute)
        end
      end
    end
  end
end
