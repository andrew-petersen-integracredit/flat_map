module Core
  module FlatMap
    module Mapping::Reader
      class Method < Basic
        delegate :mapper, :to => :mapping

        def read
          mapper.send(method, mapping)
        end

        def method
          @options[:reader]
        end
        private :method
      end
    end
  end
end
