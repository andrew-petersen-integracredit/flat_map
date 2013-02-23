module Core
  module FlatMap
    module Mapping::Writer
      # Proc writer calls a lambda passed on mapping definition and
      # sends mapper's target and value to it.
      #
      # Note that this doesn't set anything on the target itself.
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
