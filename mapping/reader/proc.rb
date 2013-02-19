module Core
  module FlatMap
    module Mapping::Reader
      class Proc < Method
        # Calls a <tt>@method</tt>, which is a {Proc} object,
        # passing +target+ object to it
        #
        # @return [Object] value returned by reader's lambda
        def read
          @method.call(target)
        end
      end
    end
  end
end
