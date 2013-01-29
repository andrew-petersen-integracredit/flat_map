module Core
  module FlatMap
    module Mapping::Writer
      class Method < Basic
        delegate :mapper, :to => :mapping

        alias_method :method, :modifier

        def write(value)
          mapper.send(method, mapping, value)
        end
      end
    end
  end
end
