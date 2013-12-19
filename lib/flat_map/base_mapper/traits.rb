module FlatMap
  # This small module allows mappers to define traits, which technically
  # means mounting anonymous mappers, attached to host one.
  module BaseMapper::Traits
    extend ActiveSupport::Concern

    # Traits class macros
    module ClassMethods
      # Define a trait for a mapper class. In implementation terms, a trait
      # is nothing more than a mounted mapper, owned by a host mapper.
      # It shares all mappings with it.
      # The block is passed as a body of the anonymous mapper class.
      #
      # @param [Symbol] name
      def trait(name, &block)
        base_class        = self < FlatMap::Mapper ? FlatMap::Mapper : FlatMap::EmptyMapper
        mapper_class      = Class.new(base_class, &block)
        mapper_class_name = "#{ancestors.first.name}#{name.to_s.camelize}Trait"
        mapper_class.singleton_class.send(:define_method, :name){ mapper_class_name }
        mount mapper_class, :trait_name => name
      end
    end

    # Override the original {FlatMap::BaseMapper::Mounting#mountings}
    # method to filter out those traited mappers that are not required for
    # trait setup of +self+. Also, handle any inline extension that may be
    # defined on the mounting mapper, which is attached as a singleton trait.
    #
    # @return [Array<FlatMap::BaseMapper>]
    def mountings
      @mountings ||= begin
        mountings = self.class.mountings.
                               reject{ |factory|
                                 factory.traited? &&
                                 !factory.required_for_any_trait?(traits)
                               }
        mountings.concat(singleton_class.mountings)
        mountings.map{ |factory| factory.create(self, *traits) }
      end
    end

    # Return a list of all mountings that represent full picture of +self+, i.e.
    # +self+ and all traits, including deeply nested, that are mounted on self
    #
    # @return [Array<FlatMap::BaseMapper>]
    def self_mountings
      mountings.select(&:owned?).map{ |mounting| mounting.self_mountings }.flatten.concat [self]
    end

    # Try to find trait mapper with name that corresponds to +trait_name+
    # Used internally to manipulate such mappers (for example, skip some traits)
    # in some scenarios.
    #
    # @param [Symbol] trait_name
    # @return [FlatMap::BaseMapper, nil]
    def trait(trait_name)
      self_mountings.find{ |mounting| mounting.class.name.underscore =~ /#{trait_name}_trait$/ }
    end

    # Return :extension trait, if present
    #
    # @return [FlatMap::BaseMapper]
    def extension
      trait(:extension)
    end

    # Return only mountings that are actually traits for host mapper.
    #
    # @return [Array<FlatMap::BaseMapper>]
    def trait_mountings
      result = mountings.select{ |mounting| mounting.owned? }
      # mapper extension has more priority then traits, and
      # has to be processed first.
      result.unshift(result.pop) if result.length > 1 && result[-1].extension?
      result
    end
    protected :trait_mountings

    # Return only mountings that correspond to external mappers.
    #
    # @return [Array<FlatMap::BaseMapper>]
    def mapper_mountings
      mountings.select{ |mounting| !mounting.owned? }
    end
    protected :mapper_mountings

    # Return +true+ if +self+ is extension of host mapper.
    #
    # @return [Boolean]
    def extension?
      owned? && self.class.name =~ /ExtensionTrait$/
    end
  end
end
