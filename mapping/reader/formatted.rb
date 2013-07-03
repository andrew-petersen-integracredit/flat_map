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
        # Additional arguments will be passed to formatting function
        # of the mapping's format.
        #
        # @return [Object] formatted value
        def read(*args)
          format_value(super, *args)
        end

        # Send the +value+ to the format method, defined in the {Format}
        # module and specified upon reader initialization.
        #
        # Additional optional arguments are passed as well.
        #
        # @param [Object] value
        # @return [Object] formatted value
        def format_value(value, *args)
          send(@format, value, *args)
        end
        private :format_value
      end
    end
  end
end
