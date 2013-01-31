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

      include Mapping
      include Mounting
      include Traits
      include ReaderMethods

      include ActiveModel::Validations

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

      def valid?
        res = super
        mounted_res = all_mountings.map(&:valid?).all?
        consolidate_errors!
        res && mounted_res
      end

      def consolidate_errors!
        mountings.map(&:errors).each do |errs|
          errors.messages.merge!(errs.to_hash){ |k, old, new| old.concat(new) }
        end
      end
      private :consolidate_errors!
    end
  end
end
