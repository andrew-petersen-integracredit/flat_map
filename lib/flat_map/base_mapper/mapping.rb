module FlatMap
  # This module hosts all definitions required to define and use mapping
  # functionality within mapper classes. This includes mapping definition
  # methods and basic reading and writing methods.
  module BaseMapper::Mapping
    extend ActiveSupport::Concern

    # Mapping class macros
    module ClassMethods
      # Mapping-modifier options to distinguish options from mappings
      # themselves:
      MAPPING_OPTIONS = [:reader, :writer, :format, :multiparam].freeze

      # Define single or multiple mappings at a time. Usually, a Hash
      # is passed in a form !{mapping_name => target_attribute}. All keys
      # that are listed under {MAPPING_OPTIONS} will be extracted and used
      # as modifiers for new mappings.
      #
      # Also, mapping names may be listed as an array preceding the hash.
      # In that case, its elements are treated as !{mapping_name => mapping_name}
      # mapping elements.
      #
      # Example:
      #   map :brand, :account_source => :source, :format => :enum
      #   # is equivalent to:
      #   map :brand => :brand, :format => :enum
      #   map :account_source => :source, :format => :enum
      def map(*args)
        mapping_options     = args.extract_options!
        mappings            = mapping_options.slice!(*MAPPING_OPTIONS)
        mappings_from_array = args.zip(args).flatten
        mappings.merge!(Hash[*mappings_from_array]) unless mappings_from_array.empty?

        define_mappings(mappings, mapping_options)
      end

      # Define a set of +mappings+, passed as a {Hash} with +options+ as modifiers.
      # Eventually, adds a mapping factories to list of class mappings. Those
      # factory objects are used to create actual mappings for specific mapper
      # object.
      #
      # @param [Hash] mappings
      # @param [Hash] options
      # @return [Array<FlatMap::Mapping::Factory>] list of mappings
      def define_mappings(mappings, options)
        mappings.each do |name, target_attribute|
          self.mappings << FlatMap::Mapping::Factory.new(name, target_attribute, options)
        end
      end
      private :define_mappings

      # List of class mappings (mapping factories).
      #
      # @return [Array<FlatMap::Mapping::Factory>]
      def mappings
        @mappings ||= []
      end

      # Writer for mappings.
      def mappings=(val)
        @mappings = val
      end
    end

    # Send passed +params+ +write_from_params+ method of each
    # of the mappings of +self+.
    #
    # Overloaded in {BaseMapper::Mounting}.
    #
    # @param [Hash] params
    # @return [Hash] params
    def write(params)
      mappings.each do |mapping|
        mapping.write_from_params(params)
      end
      params
    end

    # Send +read_as_params+ method to all mappings associated with
    # self. And consolidate results in a single hash.
    #
    # @return [Hash] set of read values
    def read
      mappings.inject({}) do |params, mapping|
        params.merge(mapping.read_as_params)
      end
    end

    # Retrieve mapping value via its name, which might differ from its
    # full_name, if suffix was used.
    #
    # @param [Symbol] name
    def [](name)
      mapping(name).try(:read)
    end

    # Write value to mapping specified by name, which might differ from its
    # full_name, if suffix was used.
    #
    # @param [Symbol] name
    # @param [Object] value
    def []=(name, value)
      mapping(name).try(:write, value)
    end

    # Lookup mapping by its name, which might differ from its
    # full_name, if suffix was used.
    #
    # @param [Symbol] name
    # @return [FlatMap::Mapping]
    def mapping(name)
      mappings.find{ |mapping| mapping.name == name }
    end

    # Return a list of mappings associated to +self+.
    #
    # @return [FlatMap::Mapping]
    def mappings
      @mappings ||= self.class.mappings.map{ |factory| factory.create(self) }
    end
    private :mappings
  end
end
