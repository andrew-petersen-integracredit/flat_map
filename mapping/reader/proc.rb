module Core
  module FlatMap
    module Mapping::Reader
      # Proc reader accepts a lambda and calls it with the target
      # as an argument for reading.
      class Proc < Method
        # Call a <tt>@method</tt>, which is a {Proc} object,
        # passing the +target+ object to it.
        #
        # @return [Object] value returned by reader's lambda
        def read
          @method.call(target)
        end
      end
    end
  end
end
