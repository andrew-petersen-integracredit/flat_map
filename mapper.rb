module Core
  module FlatMap
    class Mapper
      class NoTargetError < ArgumentError
        def initialize(mapper) super("Target object is required to initialize mapper #{mapper.inspect}"); end
      end

      extend ActiveSupport::Autoload

      autoload :Mapping
      autoload :Mounting
      autoload :Traits
      autoload :Factory
      autoload :ReaderMethods
      autoload :ModelMethods

      include Mapping
      include Mounting
      include Traits
      include ReaderMethods
      include ActiveModel::Validations
      include ModelMethods

      attr_reader :target, :traits
      attr_accessor :owner

      def initialize(target, *traits)
        raise NoTargetError.new(self) unless target.present?

        @target, @traits = target, traits
      end

      def inspect
        to_s
      end

      def owned?
        owner.present?
      end
    end
  end
end
