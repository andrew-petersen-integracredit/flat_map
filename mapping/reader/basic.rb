module Core
  module FlatMap
    module Mapping::Reader
      class Basic
        attr_reader :mapping, :options

        delegate :target, :target_attribute, :to => :mapping

        def initialize(mapping, options)
          @mapping, @options = mapping, options
        end

        def read
          target.send(target_attribute)
        end
      end
    end
  end
end
