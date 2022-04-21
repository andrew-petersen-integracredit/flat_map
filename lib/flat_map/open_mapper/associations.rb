module FlatMap
  # This module enhances and modifies original FlatMap::OpenMapper::Persistence
  # functionality for ActiveRecord models as targets.
  module OpenMapper::Associations
    extend ActiveSupport::Concern

    # ModelMethods class macros
    module ClassMethods
      # Return association list for given traits.
      # Used in ModelMapper.
      #
      # @return [nil]
      def associations(*)
        nil
      end
    end
  end
end

