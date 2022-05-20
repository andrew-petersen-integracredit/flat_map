require 'spec_helper'

module FlatMap
  module AssociationsListSpec
    # Simulate active record models.
    # Only .reflections method is used.
    Reflection = Struct.new(:klass)

    class Author
      def self.reflections; {}; end
    end

    class Link
      def self.reflections; {}; end
    end

    class Tag
      def self.reflections; {}; end
    end

    class Category
      def self.reflections; {}; end
    end

    class Comment
      # belongs_to :author
      # has_many :links

      def self.reflections
        {
          "author" => Reflection.new(Author),
          "links"  => Reflection.new(Link)
        }
      end
    end

    class Article
      # has_many :comments
      # has_many :tags

      def self.reflections
        {
          "comments" => Reflection.new(Comment),
          "tags"     => Reflection.new(Tag)
        }
      end

      def self.joins(associations); end
    end

    # Mappers for models.
    class AuthorMapper < FlatMap::ModelMapper; end

    class LinkMapper < FlatMap::ModelMapper; end

    class TagMapper < FlatMap::ModelMapper; end

    class CategoryMapper < FlatMap::ModelMapper; end

    class CommentMapper < FlatMap::ModelMapper
      trait :with_author do
        mount :author, mapper_class: AuthorMapper
      end

      trait :with_links do
        mount :links, mapper_class: LinkMapper
      end
    end

    class ArticleMapper < FlatMap::ModelMapper
      trait :with_comments do
        mount :comments, mapper_class: CommentMapper
      end

      trait :with_tags do
        mount :tags, mapper_class: TagMapper
      end

      trait :with_category do
        mount :category, mapper_class: CategoryMapper
      end
    end

    describe ".relation" do
      let(:relation) { double }
      subject { ArticleMapper.relation(%i[ with_comments with_author ]) }

      it "generates active record relation with correct associations" do
        expect(Article).to receive_message_chain(:includes, :references).
          with({ comments: :author }).with({ comments: :author }).
          and_return(relation)

        is_expected.to eq relation
      end
    end

    describe ".associations" do
      subject { ArticleMapper.associations(traits) }

      context "one mounted class" do
        let(:traits) { %i[ with_comments ] }

        it { is_expected.to eq :comments }
      end

      context "nested mounted class" do
        let(:traits) { %i[ with_comments with_author ] }

        it { is_expected.to eq({ comments: :author }) }
      end

      context "mounted and nested mounted classes" do
        let(:traits) { %i[ with_comments with_author with_tags ] }

        it { is_expected.to eq([{ comments: :author }, :tags]) }
      end

      context "two nested mounted classes" do
        let(:traits) { %i[ with_comments with_author with_links ] }

        it { is_expected.to eq({ comments: [:author, :links] }) }
      end

      context "no relation between models" do
        let(:traits) { %i[ with_category ] }

        it do
          expect { subject }.to raise_error(FlatMap::ModelMapper::Associations::AssociationError,
                                            "No association between FlatMap::AssociationsListSpec::Article " \
                                            "and FlatMap::AssociationsListSpec::Category models.")
        end
      end
    end
  end
end

