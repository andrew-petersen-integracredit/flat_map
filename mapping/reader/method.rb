module Core
  module FlatMap
    module Mapping::Reader
      # Method mapper calls a method, defined by the mapper, sending
      # the mapping object to it as an argument.
      class Method < Basic
        delegate :mapper, :to => :mapping

        # Initialize the reader with a +mapping+ and a +method+.
        #
        # @param [Core::FlatMap::Mapping] mapping
        # @param [Symbol] method name
        def initialize(mapping, method)
          @mapping, @method = mapping, method
        end

        # Send the <tt>@method</tt> to the mapping's mapper, passing
        # the mapping itself to it.
        #
        # @return [Object] value returned by reader
        def read
          mapper.send(@method, mapping)
        end
      end
    end
  end
end
