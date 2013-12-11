module FlatMap
  # Mapper factory objects are used to store mounting and trait definitions
  # and to instantiate and setup corresponding mapper objects thereafter.
  # Factory objects are stored by mapper classes in opposite to actual
  # mounted mappers that are stored by mapper objects themselves.
  class BaseMapper::Factory
    # Initializes factory with an identifier (name of a mounted mapper,
    # or the actual class for a trait) and a set of options. Those args
    # are used to create actual mapper object for the host mapper.
    #
    # @param [Symbol, Class] identifier name of a mapper or mapper class
    #   itself
    # @param [Hash] options
    def initialize(identifier, options = {}, &block)
      @identifier, @options, @extension = identifier, options, block
    end

    # Return +true+ if factory defines a trait.
    #
    # @return [Boolean]
    def traited?
      @identifier.is_a?(Class)
    end

    # Return the name of the mapper being defined by the factory.
    # Return +nil+ for the traited factory.
    #
    # @return [Symbol, nil] 
    def name
      traited? ? nil : @identifier
    end

    # Return the trait name if the factory defines a trait.
    def trait_name
      @options[:trait_name] if traited?
    end

    # Return the list of traits that should be applied for a mapper being
    # mounted on a host mapper.
    #
    # @return [Array<Symbol>] list of traits
    def traits
      Array(@options[:traits]).compact
    end

    # Return the anonymous trait class if the factory defines a trait.
    # Fetch and return the class of a mapper defined by a symbol.
    #
    # @return [Class] ancestor of {FlatMap::BaseMapper}
    def mapper_class
      return @identifier if traited?

      class_name = @options[:mapper_class_name] || "#{name.to_s.camelize}Mapper"
      class_name.constantize
    end

    # Return +true+ if factory should create targeted mapper.
    #
    # @return [Boolean]
    def targeted_mount?
      mapper_class < Mapper
    end

    # Fetch the target for the mapper being created based on target of a host mapper.
    #
    # @param [FlatMap::BaseMapper] mapper Host mapper
    # @return [Object] target for new mapper
    def fetch_target_from(mapper)
      return explicit_target!(mapper) if mapper.is_a?(EmptyMapper) && targeted_mount?

      owner_target = mapper.target

      return owner_target if traited?

      explicit_target(owner_target) || target_from_association(owner_target) || target_from_name(owner_target)
    end

    # When creating mappers mounted on top of EmptyMapper, target cannot be implicitly
    # fetched from it and should be specified explicitly.
    #
    # @param [FlatMap::EmptyMapper] mapper Host empty mapper
    # @return [Object] target for new mapper
    def explicit_target!(mapper)
      target = @options[:target]

      if target.present?
        case target
        when Proc then target.call
        when Symbol then mapper.send(target)
        else target
        end
      else
        raise Mapper::Targeting::NoTargetError.new(mapper_class)
      end
    end

    # Try to use explicit target definition passed in options to fetch a
    # target. If this value is a +Proc+, will call it with owner target as
    # argument.
    #
    # @param [Object] owner_target
    # @return [Object, nil] target for new mapper.
    def explicit_target(owner_target)
      if @options.key?(:target)
        target = @options[:target]
        if target.is_a? Proc
          target.call(owner_target)
        else
          target
        end
      end
    end

    # Try to fetch the target for a new mapper being mounted, based on
    # correspondence of the mounting name and presence of the association
    # with a similar name in the host mapper.
    #
    # For example:
    #   class Foo < ActiveRecord::Base
    #     has_one :baz
    #     has_many :bars
    #   end
    #
    #   class FooMapper < FlatMap::Mapper
    #     # target of this mapper is the instance of Foo. Lets reference it as 'foo'
    #     mount :baz # This will look for BazMapper, and will try to fetch a target for
    #                # it based on :has_one association, i.e. foo.baz || foo.build_baz
    #
    #     mount :bar # This will look for BarMapper, and will try to fetch a target for
    #                # it based on :has_many association, i.e. foo.bars.build
    #   end
    def target_from_association(owner_target)
      return unless owner_target.kind_of?(ActiveRecord::Base)

      reflection = reflection_from_target(owner_target)
      return unless reflection.present?

      case
      when reflection.macro == :has_one && reflection.options[:is_current]
        owner_target.send("effective_#{name}")
      when reflection.macro == :has_one || reflection.macro == :belongs_to
        owner_target.send(name) || owner_target.send("build_#{name}")
      when reflection.macro == :has_many
        owner_target.association(reflection.name).build
      end
    end

    # Try to retreive an association reflection that has a name corresponding
    # to the one of +self+
    #
    # @param [ActiveRecord::Base] target
    # @return [ActiveRecord::Reflection::AssociationReflection, nil]
    def reflection_from_target(target)
      return unless name.present? && target.is_a?(ActiveRecord::Base)
      reflection = target.class.reflect_on_association(name)
      reflection || target.class.reflect_on_association(name.to_s.pluralize.to_sym)
    end

    # Send the name of the mounting to the target of the host mapper, and use
    # return value as a target for a mapper being created.
    #
    # @return [Object]
    def target_from_name(target)
      target.send(name)
    end

    # Return order relative to target of the passed +mapper+ in which mapper to
    # be created should be saved. In particular, targets of <tt>:belongs_to</tt>
    # associations should be saved before target of +mapper+ is saved.
    #
    # @param [FlatMap::BaseMapper] mapper
    # @return [Symbol]
    def fetch_save_order(mapper)
      return :after if mapper.is_a?(EmptyMapper)

      reflection = reflection_from_target(mapper.target)
      return unless reflection.present?
      reflection.macro == :belongs_to ? :before : :after
    end

    # Create a new mapper object for mounting. If the factory is traited,
    # the new mapper is a part of a host mapper, and is 'owned' by it.
    # Otherwise, assign the name of the factory to it to be able to find it
    # later on.
    #
    # @param [FlatMap::BaseMapper] mapper Host mapper
    # @param [*Symbol] owner_traits List of traits to be applied to a newly created mapper
    def create(mapper, *owner_traits)
      save_order = @options[:save] || fetch_save_order(mapper) || :after
      all_traits = (traits + owner_traits).uniq

      new_one = targeted_mount? ?
        mapper_class.new(fetch_target_from(mapper), *all_traits, &@extension) :
        mapper_class.new(*all_traits, &@extension)

      if traited?
        new_one.owner = mapper
      else
        new_one.host = mapper
        new_one.name = @identifier
        new_one.save_order = save_order

        if (suffix = @options[:suffix] || mapper.suffix).present?
          new_one.suffix = suffix
          new_one.name   = :"#{@identifier}_#{suffix}"
        else
          new_one.name = @identifier
        end
      end
      new_one
    end

    # Return +true+ if the factory is required to be able to apply a trait
    # for the host mapper.
    # For example, it is required if its name is listed in +traits+.
    # It is also required if it has nested traits with names listed in +traits+.
    #
    # @param [Array<Symbol>] traits list of traits
    # @return [Boolean]
    def required_for_any_trait?(traits)
      return true unless traited?

      traits.include?(trait_name) ||
        mapper_class.mountings.any?{ |factory|
          factory.traited? &&
          factory.required_for_any_trait?(traits)
        }
    end
  end
end
