module Core
  module FlatMap
    class Mapper
      extend ActiveSupport::Autoload
      autoload :Mapping
      autoload :Mounting
      autoload :Factory

      include Mapping
      include Mounting

      attr_reader :target

      def initialize(target)
        @target = target
      end
    end
  end
end
