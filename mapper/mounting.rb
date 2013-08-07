module Core
  module FlatMap
    # This module hosts definitions required for mounting functionality
    # of the mappers. This includes mounting definition methods, overloaded
    # +read+ and +write+ methods to make them aware of mounted mappers and
    # other methods.
    #
    # Also, the +method_missing+ method is defined here to delegate the missing
    # method to the very first mounted mapper that responds to it.
    module Mapper::Mounting
      extend ActiveSupport::Concern

      included do
        attr_accessor :save_order
      end

      # Mounting class macros.
      module ClassMethods
        # Add a mounting factory to a list of factories of a class
        # These factories are used to create actual mounted objects,
        # which are mappers themselves, associated to a particular
        # mapper.
        #
        # @param [*Object] args
        # @return [Array<Core::FlatMap::Mapper::Factory>]
        def mount(*args, &block)
          mountings << FlatMap::Mapper::Factory.new(*args, &block)
        end

        # List of mountings (factories) of a class.
        #
        # @return [Array<Core::FlatMap::Mapper>]
        def mountings
          @mountings ||= []
        end

        # Writer for @mountings.
        def mountings=(val)
          @mountings = val
        end
      end

      # Extend original {Core::FlatMap::Mapping#read} method to take
      # into account mountings of mounted mappers.
      #
      # @return [Hash] read values
      def read
        mountings.inject(super) do |result, mapper|
          result.merge(mapper.read)
        end
      end

      # Extend original {Core::FlatMap::Mapping#write} method to pass
      # +params+ to mounted mappers.
      #
      # Overridden in {ModelMethods}. Left here for consistency.
      #
      # @param [Hash] params
      # @return [Hash] params
      def write(params)
        super

        mountings.each do |mapper|
          mapper.write(params)
        end

        params
      end

      # Return list of mappings to be saved before saving target of +self+
      #
      # @return [Array<Core::FlatMap::Mapper>]
      def before_save_mountings
        nearest_mountings.select{ |m| m.save_order == :before }
      end

      # Return list of mappings to be saved after target of +self+ was saved
      #
      # @return [Array<Core::FlatMap::Mapper>]
      def after_save_mountings
        nearest_mountings.reject{ |m| m.save_order == :before }
      end

      # Return all mountings that are mouted on +self+ directly or through
      # traits.
      #
      # @return [Array<Core::FlatMap::Mapper>]
      def nearest_mountings
        mountings.map{ |m| m.owned? ? m.nearest_mountings : m }.flatten
      end

      # Return a list of all mountings (mapper objects) associated with +self+.
      #
      # Overridden in {Traits}. Left here for consistency.
      #
      # @return [Array<Core::FlatMap::Mapper>]
      def mountings
        @mountings ||= self.class.mountings.map{ |factory| factory.create(self) }
      end

      # Return a mapping with the name that corresponds to passed +mounting_name+,
      # if it exists.
      #
      # @return [Core::FlatMap::Mapping, nil]
      def mounting(mounting_name, deep = true)
        list = deep ? all_mountings : mountings
        list.find{ |mount| mount.name == mounting_name }
      end

      # Return a list of all mounted mappers. If +self+ is a trait, return a
      # list of all mountings of the owner. This will allow separate traits
      # to share methods via method_missing pattern.
      #
      # @return [Array<Core::FlatMap::Mapper>] mounted mappers (including traits)
      def all_mountings
        return all_nested_mountings.unshift(self) unless owned?
        owner.all_mountings
      end
      protected :all_mountings

      # Return a list of mountings that are accessible by a named mapper.
      #
      # @return [Array<Core::FlatMap::Mapper>]
      def all_nested_mountings
        mountings.dup.concat(mountings.map{ |m| m.send(:all_nested_mountings) }).flatten
      end
      protected :all_nested_mountings

      # Return a list of all mappings, i.e. mappings associated to +self+,
      # plus mappings of all deeply mounted mappers. If +self+ is the owner,
      # that means it is a part (a trait) of a host mapper. That means that all
      # mappings of it actually correspond to all mappings of a host mapper.
      # This allows to define things like validation in a trait where access
      # to top-level mappings is required.
      #
      # @return [Array<Core::FlatMap::Mapping>]
      def all_mappings
        return all_nested_mappings unless owned?
        owner.all_mappings
      end
      protected :all_mappings

      # Return a list of all mappings, i.e. mappings that associated to +self+
      # plus mappings of all deeply mounted mappers.
      #
      # @return [Array<Core::FlatMap::Mapping>]
      def all_nested_mappings
        (mappings + mountings.map{ |m| m.send(:all_nested_mappings) }).flatten
      end
      protected :all_nested_mappings

      # Delegate missing method to any mounted mapping that respond to it,
      # unless those methods are protected methods of Core::FlatMap::Mapper.
      #
      # NOTE: :to_ary method is called internally by Ruby 1.9.3 when we call
      # something like [mapper].flatten. And we DO want default behavior
      # for handling this missing method.
      def method_missing(name, *args, &block)
        return super if name == :to_ary || Core::FlatMap::Mapper.protected_instance_methods.include?(name)

        mounting = all_mountings.find{ |m| m.respond_to?(name) }
        return super if mounting.nil?
        mounting.send(name, *args, &block)
      end
    end
  end
end
