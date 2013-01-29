module Core
  module FlatMap
    module Mapping::Reader
      class Formatted < Basic
        extend ActiveSupport::Autoload
        autoload :Formats

        include Formats

        def read
          format_value super
        end

        def format
          @options[:format]
        end
        private :format

        def format_value(value)
          send(format, value)
        end
        private :format_value
      end
    end
  end
end
