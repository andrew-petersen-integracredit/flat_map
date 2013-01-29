module Core
  module FlatMap
    module Mapping::Writer
      class Proc < Method
        def write(value)
          method.call(target, value)
        end
      end
    end
  end
end
