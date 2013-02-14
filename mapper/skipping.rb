module Core
  module FlatMap
    module Mapper::Skipping
      def skip!
        @_skip_processing = true
      end

      def use!
        @_skip_processing = nil
      end

      def skipped?
        !!@_skip_processing
      end

      def valid?
        if skipped?
          target.destroy if target.new_record?
          true
        else
          super
        end
      end

      def save
        skipped? || super
      end

      def write(*)
        use!
        super
      end

      def method_missing(name, *args, &block)
        mounting = all_mountings.find{ |m| m.respond_to?(name) }
        return super if mounting.nil?
        mounting.send(name, *args, &block)
      end
    end
  end
end
