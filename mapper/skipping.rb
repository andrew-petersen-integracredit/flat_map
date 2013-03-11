module Core
  module FlatMap
    # This helper module provides helper functionality that allow to
    # exclude specific mapper from a processing chain.
    module Mapper::Skipping
      # Mark self as skipped, i.e. it will not be subject of
      # validation and saving chain.
      #
      # Note that this will also mark the target record as
      # destroyed if it is a new record. Thus, this
      # record will not be a subject of Rails associated
      # validation procedures, and will not be saved as an
      # associated record.
      #
      # @return [Object]
      def skip!
        @_skip_processing = true

        # Using the instance variable directly as {ActiveRecord::Base#delete}
        # will freeze the record.
        if target.is_a?(ActiveRecord::Base)
          target.instance_variable_set('@destroyed', true) if target.new_record?
        end
      end

      # Remove "skip" mark from +self+ and "destroyed" flag from
      # the target.
      #
      # @return [Object]
      def use!
        @_skip_processing = nil

        if target.is_a?(ActiveRecord::Base)
          target.instance_variable_set('@destroyed', false) 
        end
      end

      # Return +true+ if +self+ was marked for skipping.
      #
      # @return [Boolean]
      def skipped?
        !!@_skip_processing
      end

      # Override {Core::FlatMap::Mapper::ModelMethods#valid?} to
      # force it to return +true+ if +self+ is marked for skipping.
      #
      # @return [Boolean]
      def valid?
        skipped? || super
      end

      # Override {Core::FlatMap::Mapper::ModelMethods#save} method to
      # force it to return +true+ if +self+ is marked for skipping.
      #
      # @return [Boolean]
      def save
        skipped? || super
      end

      # Mark self as used and then delegated to original
      # {Core::FlatMap::Mapper::ModelMethods#write}.
      def write(*)
        use!
        super
      end
    end
  end
end
