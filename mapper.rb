module Core
  module FlatMap
    class Mapper
      class NoTargetError < ArgumentError
        def initialize() super("Target object is required to initialize mapper"); end
      end

      extend ActiveSupport::Autoload

      autoload :Mapping
      autoload :Mounting
      autoload :Traits
      autoload :Factory

      include Mapping
      include Mounting
      include Traits

      attr_reader :target, :traits

      def initialize(target, *traits)
        raise NoTargetError unless target.present?

        @target, @traits = target, traits
      end
    end
  end
end
