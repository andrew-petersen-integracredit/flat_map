module FlatMap
  # This module enhances and modifies original FlatMap::OpenMapper::Persistence
  # functionality for ActiveRecord models as targets.
  module ModelMapper::AssociationsList
    extend ActiveSupport::Concern

    # ModelMethods class macros
    module ClassMethods
      # Return associations list for given traits based on current mapper mounding.
      #
      # @param traits [Array<Symbol>]
      # @return [Array|Hash]
      def associations_for_traits(traits)
        build_associations(traits, target_class, false)
      end

      # Return associations list for given traits based on current mapper mounding.
      #
      # @param traits [Array<Symbol>]
      # @param context [ActiveRecord::Base]
      # @param include_self [Boolean]
      # @return [Array|Hash]
      protected def build_associations(traits, context, include_self)
        classes_list = find_dependency_classes(traits)

        convert_classes_to_associations(context, classes_list, include_self)
      end

      # Return associations list for given traits based on current mapper mounding.
      #
      # @param traits [Array<Symbol>]
      # @return [Array<Symbol>]
      private def find_dependency_classes(traits)
        mountings.map do |mounting|
          mapper_class = mounting.mapper_class

          if mounting.traited?
            mapper_class.build_associations(traits, target_class, false) if mounting.trait_name.in?(traits)
          else
            mapper_class.build_associations(traits, target_class, true)
          end
        end.compact
      end

      # Convert given classes to association object.
      #
      # @param context [ActiveRecord::Base]
      # @param classes_list [Array<ActiveRecord::Base>]
      # @return [Symbol|Array|Hash]
      private def convert_classes_to_associations(context, classes_list, include_self)
        if classes_list.count.zero?
          include_self ? association_name_for_class(context) : nil
        else
          classes_list = classes_list.first if classes_list.length == 1

          include_self ? { association_name_for_class(context) => classes_list } : classes_list
        end
      end

      # Return association name for target_class in given context.
      #
      # @param context [ActiveRecord::Base]
      # #return [Symbol|nil]
      private def association_name_for_class(context)
        context.reflections.find do |_, reflection|
          reflection.klass == target_class
        end.first.to_sym
      end
    end
  end
end

