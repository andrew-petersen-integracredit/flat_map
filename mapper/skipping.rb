module Core
  module FlatMap
    # This helper module provides helper functionality that allow to
    # exclude specific mapper from a processing chain.
    module Mapper::Skipping
      # Mark self as skipped, i.e. it will not be subject of
      # validation and saving chain.
      #
      # @return [true]
      def skip!
        @_skip_processing = true
      end

      # Removes "skip" mark from +self+
      #
      # @return [nil]
      def use!
        @_skip_processing = nil
      end

      # Return +true+ if +self+ was marked for skipping
      #
      # @return [Boolean]
      def skipped?
        !!@_skip_processing
      end

      # Overrides {Core::FlatMap::Mapper::ModelMethods#valid?} to
      # force it to return +true+ if +self+ is marked for skipping.
      #
      # @return [Boolean]
      def valid?
        skipped? || super
      end

      # Overrides {Core::FlatMap::Mapper::ModelMethods#save} method to
      # force it to return +true+ if +self+ is marked for skipping.
      # Note that this will also mark target record for
      # destruction if it is a new record. Thus, this
      # record will not be a subject of Rails associated
      # validation procedures, and will not be save as
      # associated record.
      #
      # @return [Boolean]
      def save
        if skipped?
          target.destroy if target.respond_to?(:new_record?) && target.new_record?
          true
        else
          super
        end
      end

      # Marks self as used and then delegated to original
      # {Core::FlatMap::Mapper::ModelMethods#write}
      def write(*)
        use!
        super
      end
    end
  end
end
