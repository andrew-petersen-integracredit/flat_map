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
      autoload :AttributeMethods
      autoload :ModelMethods
      autoload :Skipping

      include Mapping
      include Mounting
      include Traits
      include AttributeMethods
      include ActiveModel::Validations
      include ModelMethods
      include Skipping

      attr_reader :target, :traits
      attr_accessor :owner, :name

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
