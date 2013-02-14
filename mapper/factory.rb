module Core
  module FlatMap
    class Mapper::Factory
      def initialize(identifier, options = {})
        @identifier, @options = identifier, options
      end

      def traited?
        @identifier.is_a?(Class)
      end

      def name
        traited? ? nil : @identifier
      end

      def trait_name
        @options[:trait_name] if traited?
      end

      def traits
        Array(@options[:traits]).compact
      end

      def mapper_class
        return @identifier if traited?

        class_name = @options[:mapper_class_name] || "#{name.to_s.camelize}Mapper"
        class_name.constantize
      end

      def fetch_target(mapper)
        owner_target = mapper.target

        return owner_target if traited?

        target_from_association(owner_target) || target_from_name(owner_target)
      end

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

      def target_from_name(target)
        target.send(name)
      end

      def create(mapper, *owner_traits)
        new_one = mapper_class.new(fetch_target(mapper), *(traits + owner_traits).uniq)
        if traited?
          new_one.owner = mapper
        else
          new_one.name = @identifier
        end
        new_one
      end

      def required_for_any_trait?(traits)
        return true unless traited?

        traits.include?(trait_name) ||
          mapper_class.mountings.any?{ |factory| factory.traited? && factory.required_for_any_trait?(traits) }
      end
    end
  end
end
