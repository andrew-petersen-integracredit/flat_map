module Core
  module FlatMap
    module Mapping::Writer
      class Basic
        attr_reader :mapping, :modifier

        delegate :target, :target_attribute, :to => :mapping

        def initialize(mapping, modifier)
          @mapping, @modifier = mapping, modifier
        end

        def write(value)
          target.send("#{target_attribute}=", value)
        end
      end
    end
  end
end
