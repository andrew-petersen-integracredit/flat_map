module Core
  module FlatMap
    module Mapping::Reader
      class Proc < Method
        delegate :mapper, :to => :mapping

        def read
          method.call(target)
        end
      end
    end
  end
end
