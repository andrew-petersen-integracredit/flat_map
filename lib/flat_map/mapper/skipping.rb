module FlatMap
  # This helper module provides helper functionality that allow to
  # exclude specific mapper from a processing chain.
  module Mapper::Skipping
    extend ActiveSupport::Autoload

    autoload :ActiveRecord

    # Mark self as skipped, i.e. it will not be subject of
    # validation and saving chain.
    #
    # @return [Object]
    def skip!
      @_skip_processing = true
    end

    # Remove "skip" mark from +self+ and "destroyed" flag from
    # the target.
    #
    # @return [Object]
    def use!
      @_skip_processing = nil
    end

    # Return +true+ if +self+ was marked for skipping.
    #
    # @return [Boolean]
    def skipped?
      !!@_skip_processing
    end

    # Override {FlatMap::Mapper::ModelMethods#valid?} to
    # force it to return +true+ if +self+ is marked for skipping.
    #
    # @param [Symbol] context useless context parameter to make it compatible with
    #   ActiveRecord models.
    #
    # @return [Boolean]
    def valid?(context = nil)
      skipped? || super
    end

    # Override {FlatMap::Mapper::ModelMethods#save} method to
    # force it to return +true+ if +self+ is marked for skipping.
    #
    # @return [Boolean]
    def save
      skipped? || super
    end

    # Override {FlatMap::Mapper::ModelMethods#shallow_save} method
    # to make it possible to skip traits.
    #
    # @return [Boolean]
    def shallow_save
      skipped? || super
    end

    # Mark self as used and then delegated to original
    # {FlatMap::Mapper::ModelMethods#write}.
    def write(*)
      use!
      super
    end
  end
end
