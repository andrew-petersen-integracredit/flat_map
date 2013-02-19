module Core
  module FlatMap
    module Mapping::Writer
      class Proc < Method
        # Calls a <tt>@method</tt>, which is a +Proc+ object,
        # passing it mapping's +target+ and +value
        #
        # @param [Object] value
        # @return [Object] result of writing
        def write(value)
          @method.call(target, value)
        end
      end
    end
  end
end
