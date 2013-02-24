module Core
  module FlatMap
    # Mapper factory objects are used to store mounting and trait definitions
    # and to instantiate and setup corresponding mapper objects thereafter.
    # Factory objects are stored by mapper classes in opposite to actual
    # mounted mappers that are stored by mapper objects themselves.
    class Mapper::Factory
      # Initializes factory with an identifier (name of a mounted mapper,
      # or the actual class for a trait) and a set of options. Those args
      # are used to create actual mapper object for the host mapper.
      #
      # @param [Symbol, Class] identifier name of a mapper or mapper class
      #   itself
      # @param [Hash] options
      def initialize(identifier, options = {})
        @identifier, @options = identifier, options
      end

      # Return +true+ if factory defines a trait
      #
      # @return [Boolean]
      def traited?
        @identifier.is_a?(Class)
      end

      # Return name of a mapper being defined by the factory.
      # Return +nil+ for the traited factory
      #
      # @return [Symbol, nil] 
      def name
        traited? ? nil : @identifier
      end

      # Return trait name if factory defines a trait.
      def trait_name
        @options[:trait_name] if traited?
      end

      # Return list of traits that should be applied for a mapper being
      # mounted on a host one
      #
      # @return [Array<Symbol>] list of traits
      def traits
        Array(@options[:traits]).compact
      end

      # Return a anonymous trait class if factory defines a trait.
      # Fetch and return a class of a mapper defined by a symobl
      #
      # @return [Class] ancestor of {Core::FlatMap::Mapper}
      def mapper_class
        return @identifier if traited?

        class_name = @options[:mapper_class_name] || "#{name.to_s.camelize}Mapper"
        class_name.constantize
      end

      # Fetch target for a mapper being created based on target of a host mapper.
      #
      # @param [Core::FlatMap::Mapper] mapper Host mapper
      # @return [Object] target for new mapper
      def fetch_target(mapper)
        owner_target = mapper.target

        return owner_target if traited?

        target_from_association(owner_target) || target_from_name(owner_target)
      end

      # Try to fetch target for a new mapper being mounted, based on correspondence
      # of the mounting name and presence of the association with a similar name in
      # the host mapper.
      #
      # For example:
      #   class Foo < ActiveRecord::Base
      #     has_one :baz
      #     has_many :bars
      #   end
      #
      #   class FooMapper < Core::FlatMap::Mapper
      #     # target of this mapper is the instance of Foo. Lets reference it as 'foo'
      #     mount :baz # This will look for BazMapper, and will try to fetch a target for
      #                # it based on :has_one assoication, i.e. foo.baz || foo.build_baz
      #
      #     mount :bar # This will look for BarMapper, and will try to fetch a target for
      #                # it based on :has_many association, i.e. foo.bars.build
      #   end
      def target_from_association(owner_target)
        return unless owner_target.kind_of?(ActiveRecord::Base)

        if @options.key?(:mounting_point)
          return @options[:mounting_point].call(owner_target)
        end

        reflection = owner_target.class.reflect_on_association(name)
        reflection ||= owner_target.class.reflect_on_association(name.to_s.pluralize.to_sym)
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

      # Simply sends a name of a mounting to the target of a host mapper, and use
      # return value as a target for a mapper being created.
      def target_from_name(target)
        target.send(name)
      end

      # Creates a new mapper object for mounting. If factory is traited, the new mapper
      # is a part of a host mapper, and is 'owned' by it. In other case, assign a name
      # of a factory to it to be able to find it later on.
      #
      # @param [Core::FlatMap::Mapper] mapper Host mapper
      # @param [*Symbol] owner_traits List of traits to be applied to a newly created mapper
      def create(mapper, *owner_traits)
        new_one = mapper_class.new(fetch_target(mapper), *(traits + owner_traits).uniq)
        if traited?
          new_one.owner = mapper
        else
          new_one.name = @identifier
        end
        new_one
      end

      # Return +true+ if factory is requied to be able to apply a trait for a host mapper.
      # For example, it is required if its name is listed in +traits+, as well as it is
      # required if has nested traits with names listed in +traits+
      #
      # @param [Array<Symbol>] traits list of traits
      # @return [Boolean]
      def required_for_any_trait?(traits)
        return true unless traited?

        traits.include?(trait_name) ||
          mapper_class.mountings.any?{ |factory| factory.traited? && factory.required_for_any_trait?(traits) }
      end
    end
  end
end
