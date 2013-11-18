module FlatMap
  module Mapping::Writer
    # Basic writer simply calls the target's attribute assignment method
    # passing to it the value being written.
    class Basic
      attr_reader :mapping

      delegate :target, :target_attribute, :to => :mapping

      # Initialize writer by passing +mapping+ to it.
      def initialize(mapping)
        @mapping = mapping
      end

      # Call the assignment method of the target, passing
      # the +value+ to it.
      #
      # @param [Object] value
      # @return [Object] result of assignment
      def write(value)
        target.send("#{target_attribute}=", value)
      end
    end
  end
end
