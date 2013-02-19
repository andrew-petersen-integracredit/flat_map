module Core
  module FlatMap
    class Mapper
      class NoTargetError < ArgumentError
        # Initializes exception with a describing message for +mapper+
        #
        # @param [Core::FlatMap::Mapper] mapper
        def initialize(mapper)
          super("Target object is required to initialize mapper #{mapper.inspect}")
        end
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

      # Initializes +mapper+ with +target+ and +traits+, which are
      # used to fetch proper list of mounted mappers. Raises error
      # if target is not specified.
      #
      # @param [Object] target of mapping
      # @param [*Symbol] list of traits
      # @raise [Core::FlatMap::Mapper::NoTargetError]
      def initialize(target, *traits)
        raise NoTargetError.new(self) unless target.present?

        @target, @traits = target, traits
      end

      # Return a simple string representation of +mapper+. Done so to
      # avoid really long inspection of internal objects (target -
      # usually AR model, mountings and mappings)
      # @return [String]
      def inspect
        to_s
      end

      # Return +true+ if +mapper+ is owned. This means that current
      # mapper is actually a trait. Thus, it is a part of an owner
      # mapper.
      #
      # @return [Boolean]
      def owned?
        owner.present?
      end
    end
  end
end
