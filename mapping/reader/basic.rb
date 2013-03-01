module Core
  module FlatMap
    module Mapping::Reader
      # Basic reader simply sends a mapped attribute to the target
      # and returns the result value.
      class Basic
        attr_reader :mapping

        delegate :target, :target_attribute, :to => :mapping

        # Initialize the reader with a mapping.
        #
        # @param [Core::FlatMap::Mapping] mapping
        def initialize(mapping)
          @mapping = mapping
        end

        # Send the attribute method to the target and return its value.
        #
        # @return [Object] value returned by reading
        def read
          target.send(target_attribute)
        end
      end
    end
  end
end
