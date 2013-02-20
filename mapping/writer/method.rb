module Core
  module FlatMap
    module Mapping::Writer
      # Method writer calls a method defined by mapper and sends mapping
      # and value to it as arguments
      class Method < Basic
        delegate :mapper, :to => :mapping

        # Initializes writer with mapping and method name
        # that should be called upon mapping's mapper
        #
        # @param [Core::FlatMap::Mapping] mapping
        # @param [Symbol] method
        def initialize(mapping, method)
          @mapping, @method = mapping, method
        end

        # Writes a +value+ by sending it, alongside with
        # mapping itself
        #
        # @param [Object] value
        # @return [Object] result of writing
        def write(value)
          mapper.send(@method, mapping, value)
        end
      end
    end
  end
end
