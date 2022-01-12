module FlatMap
  # This module enhances and modifies original FlatMap::OpenMapper::Persistence
  # functionality for ActiveRecord models as targets.
  module OpenMapper::JoinsList
    extend ActiveSupport::Concern

    # ModelMethods class macros
    module ClassMethods
      def joins_for_traits(*)
        nil
      end
    end
  end
end

