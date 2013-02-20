module Core
  module FlatMap
    module Mapping::Reader
      # Method mapper calls a method, defined by mapper, sending
      # mapping object to it as an argument.
      class Method < Basic
        delegate :mapper, :to => :mapping

        # Initializes reader with +mapping+ and +method+
        #
        # @param [Core::FlatMap::Mapping] mapping
        # @param [Symbol] method name
        def initialize(mapping, method)
          @mapping, @method = mapping, method
        end

        # Sends <tt>@method</tt> to mapping's mapper, passing
        # mapping itself to it
        #
        # @return [Object] value returned by reader
        def read
          mapper.send(@method, mapping)
        end
      end
    end
  end
end
