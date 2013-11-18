module FlatMap
  module Mapping::Writer
    # Method writer calls a method defined by mapper and sends mapping
    # and value to it as arguments.
    #
    # Note that this doesn't set anything on the target itself.
    class Method < Basic
      delegate :mapper, :to => :mapping

      # Initialize the writer with a +mapping+ and +method+ name
      # that should be called on the mapping's mapper.
      #
      # @param [FlatMap::Mapping] mapping
      # @param [Symbol] method
      def initialize(mapping, method)
        @mapping, @method = mapping, method
      end

      # Write a +value+ by sending it, along with the mapping itself.
      #
      # @param [Object] value
      # @return [Object] result of writing
      def write(value)
        mapper.send(@method, mapping, value)
      end
    end
  end
end
