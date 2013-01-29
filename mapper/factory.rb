module Core
  module FlatMap
    class Mapper::Factory
      def initialize(name, options = {})
        @name, @options = name, options
      end

      def mapper_class
        class_name = @options[:mapper_class_name] || "#{@name.to_s.camelize}Mapper"
        class_name.constantize
      end

      def fetch_target(mapper)
        mapper_target = mapper.target
        target_from_association(mapper_target) || target_from_name(mapper_target)
      end

      def target_from_association(target)
        return unless target.kind_of?(ActiveRecord::Base)
        return unless (association = target.association(@name)).present?
        if association.reflection.macro == :has_one && association.reflection.options[:is_current]
          target.send("effective_#{@name}")
        end
      end

      def target_from_name(target)
        target.send(@name)
      end

      def create(mapper)
        mapper_class.new(fetch_target(mapper))
      end
    end
  end
end
