module Core
  module FlatMap
    module Mapper::Mapping
      extend ActiveSupport::Concern

      module ClassMethods
        MAPPING_OPTIONS = [:reader, :writer, :format, :multiparam].freeze

        def map(*args)
          mapping_options = args.extract_options!
          mappings = mapping_options.slice!(*MAPPING_OPTIONS)
          mappings_from_array = args.zip(args).flatten
          mappings.merge!(Hash[*mappings_from_array]) unless mappings_from_array.empty?

          define_mappings(mappings, mapping_options)
        end

        def define_mappings(mappings, options)
          mappings.each do |name, target_attribute|
            self.mappings << FlatMap::Mapping::Factory.new(name, target_attribute, options)
          end
        end
        private :define_mappings

        def mappings
          @mappings ||= []
        end
      end

      # Overloaded by {ModelMethods}
      def write(params)
        mappings.each do |mapping|
          mapping.write_from_params(params)
        end
        params
      end

      def read
        mappings.inject({}) do |params, mapping|
          params.merge(mapping.read_as_params)
        end
      end

      def mappings
        @mappings ||= self.class.mappings.map{ |factory| factory.create(self) }
      end
      private :mappings
    end
  end
end
