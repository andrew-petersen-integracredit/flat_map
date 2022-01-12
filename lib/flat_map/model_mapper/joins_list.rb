module FlatMap
  # This module enhances and modifies original FlatMap::OpenMapper::Persistence
  # functionality for ActiveRecord models as targets.
  module ModelMapper::JoinsList
    extend ActiveSupport::Concern

    # ModelMethods class macros
    module ClassMethods
      def joins_for_traits(traits, include_self = false)
        joins_list = find_current_mapper_joins(traits)

        prepare_joins_list_object(include_self, joins_list)
      end

      private def find_current_mapper_joins(traits)
        mountings.map do |mounting|
          mapper_class = mounting.mapper_class

          if mounting.traited?
            mapper_class.joins_for_traits(traits, false) if mounting.trait_name.in?(traits)
          else
            mapper_class.joins_for_traits(traits, true)
          end
        end.compact
      end

      private def prepare_joins_list_object(include_self, joins_list)
        case joins_list.count
        when 0
          include_self ? target_class : nil
        when 1
          join = association_name_for_join(joins_list.first)

          include_self ? { target_class => join } : join
        else
          joins = joins_list.map { |join_class| association_name_for_join(join_class) }

          include_self ? { target_class => joins } : joins
        end
      end

      private def association_name_for_join(join)
        if join.is_a?(Hash)
          {
            association_name_for_class(join.keys.first) => join.values.first
          }
        else
          association_name_for_class(join)
        end
      end

      private def association_name_for_class(associated_class)
        return associated_class if associated_class.is_a?(Symbol)

        target_class.reflections.find do |name, _|
          target_class.reflect_on_association(name).klass == associated_class
        end.first.to_sym
      end
    end
  end
end

