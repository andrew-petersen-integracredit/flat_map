module FlatMap
  # This module enhances and modifies original FlatMap::OpenMapper::Persistence
  # functionality for ActiveRecord models as targets.
  module ModelMapper::Associations
    extend ActiveSupport::Concern

    # Raised when there is no active record association between models.
    class AssociationError < StandardError; end

    # ModelMethods class macros
    module ClassMethods
      # Build relation for given traits.
      # Allows to create relation which loads data from all tables related to given traits.
      # For example:
      #
      # class CommentMapper < FlatMap::ModelMapper
      # end
      #
      # class ArticleMapper < FlatMap::ModelMapper
      #   trait :with_comments do
      #     mount :comments, mapper_class: CommentMapper
      #   end
      # end
      #
      # Following call:
      # ArticleMapper.relation(%i[with_comments]).where(...)
      #
      # is same as:
      # Article.includes(:comments).where(...)
      #
      #
      # @param traits [Array<Symbol>]
      # @return [ActiveRecord::Relation]
      def relation(traits)
        target_class.includes(associations(traits))
      end

      # Return associations list for given traits based on current mapper mounding.
      # This method allows to receive associations list for given traits.
      # Then associations list could be used as parameters for .joins method
      # to build active record relation to select data form tables related to traits.
      # For example:
      #
      # class AuthorMapper < FlatMap::ModelMapper
      # end
      #
      # class TagMapper < FlatMap::ModelMapper
      # end
      #
      # class CommentMapper < FlatMap::ModelMapper
      #   trait :with_author do
      #     mount :author, mapper_class: AuthorMapper
      #   end
      # end
      #
      # class ArticleMapper < FlatMap::ModelMapper
      #   trait :with_comments do
      #     mount :comments, mapper_class: CommentMapper
      #   end
      #
      #   trait :with_tags do
      #     mount :tags, mapper_class: TagMapper
      #   end
      # end
      #
      # ArticleMapper.associations(%i[ with_comments ])
      # => :comments
      #
      # ArticleMapper.associations(%i[ with_tags ])
      # => :tags
      #
      # ArticleMapper.associations(%i[ with_comments with_tags ])
      # => [:comments, :tags]
      #
      # ArticleMapper.associations(%i[ with_comments with_author ])
      # => { comments: :author }
      #
      #
      # @param traits [Array<Symbol>]
      # @return       [Array|Hash]
      def associations(traits)
        build_associations(traits, target_class, false)
      end

      # Return associations list for given traits based on current mapper mounding.
      #
      # @param traits       [Array<Symbol>]
      # @param context      [ActiveRecord::Base]
      # @param include_self [Boolean]
      # @return             [Array|Hash]
      protected def build_associations(traits, context, include_self)
        classes_list = find_dependency_classes(traits)

        map_classes_to_associations(context, classes_list, include_self)
      end

      # Return associations list for given traits based on current mapper mounding.
      #
      # @param traits [Array<Symbol>]
      # @return       [Array<Symbol>]
      private def find_dependency_classes(traits)
        mountings.map do |mounting|
          mapper_class = mounting.mapper_class

          if mounting.traited?
            mapper_class.build_associations(traits, target_class, false) if traits.include?(mounting.trait_name)
          else
            mapper_class.build_associations(traits, target_class, true)
          end
        end.compact
      end

      # Map given classes to association object names.
      #
      # @param context      [ActiveRecord::Base]
      # @param classes_list [Array<ActiveRecord::Base>]
      # @return             [Symbol|Array|Hash]
      private def map_classes_to_associations(context, classes_list, include_self)
        if classes_list.count.zero?
          include_self ? association_for_class(context) : nil
        else
          classes_list = classes_list.first if classes_list.length == 1

          include_self ? { association_for_class(context) => classes_list } : classes_list
        end
      end

      # Return association name for target_class in given context.
      #
      # @param context [ActiveRecord::Base]
      # #return        [Symbol|nil]
      private def association_for_class(context)
        reflection = context.reflections.find do |_, reflection|
          reflection.klass == target_class
        end

        unless reflection
          raise AssociationError, "No association between #{context.name} and #{target_class.name} models."
        end

        reflection.first.to_sym
      end
    end
  end
end

