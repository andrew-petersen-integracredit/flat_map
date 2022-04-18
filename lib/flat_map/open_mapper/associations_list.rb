module FlatMap
  # This module enhances and modifies original FlatMap::OpenMapper::Persistence
  # functionality for ActiveRecord models as targets.
  module OpenMapper::AssociationsList
    extend ActiveSupport::Concern

    # ModelMethods class macros
    module ClassMethods
      def associations_for_traits(*)
        nil
      end
    end
  end
end

