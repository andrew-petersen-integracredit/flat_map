module Core
  module FlatMap
    module Mapping::Reader
      # Formatted reader reads the value the same as Basic reader does, but
      # additionally performs value postprocessing. All processing methods
      # are defined within {Formatted::Formats} module. The method is chosen
      # based on the :format option when the mapping is defined.
      class Formatted < Basic
        extend ActiveSupport::Autoload
        autoload :Formats

        include Formats

        # Initialize the reader with a +mapping+ and a +format+.
        #
        # @param [Core::FlatMap::Mapping] mapping
        # @param [Symbol] format
        def initialize(mapping, format)
          @mapping, @format = mapping, format
        end

        # Read the value just like the {Basic} reader does, but
        # additionally send the returned value to its format method.
        #
        # @return [Object] formatted value
        def read
          format_value super
        end

        # Send the +value+ to the format method, defined in the {Format}
        # module and specified upon reader initialization.
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
