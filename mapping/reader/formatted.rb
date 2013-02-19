module Core
  module FlatMap
    module Mapping::Reader
      class Formatted < Basic
        extend ActiveSupport::Autoload
        autoload :Formats

        include Formats

        # Initializes reader with +mapping+ and +format+
        #
        # @param [Core::FlatMap::Mapping] mapping
        # @param [Symbol] format
        def initialize(mapping, format)
          @mapping, @format = mapping, format
        end

        # Reads the value just like the {Basic} reader does, but
        # additionally sends returned value to its format method
        #
        # @return [Object] formatted value
        def read
          format_value super
        end

        # Sends +value+ to one of format method, defined in {Format}
        # module and specified on reader initialization
        #
        # @param [Object] value
        # @return [Object] formatted value
        def format_value(value)
          send(@format, value)
        end
        private :format_value
      end
    end
  end
end
