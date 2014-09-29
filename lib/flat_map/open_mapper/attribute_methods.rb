module FlatMap
  # This module allows mappers to return and assign values via method calls
  # which names correspond to names of mappings defined within the mapper.
  #
  # This methods are defined within anonymous module that will extend
  # mapper on first usage of this methods.
  #
  # NOTE: :to_ary method is called internally by Ruby 1.9.3 when we call
  # something like [mapper].flatten. And we DO want default behavior
  # for handling this missing method.
  module OpenMapper::AttributeMethods
    # Lazily define reader and writer methods for all mappings available
    # to the mapper, and extend +self+ with it.
    def method_missing(name, *args, &block)
      if name == :to_ary ||
          @attribute_methods_defined ||
          self.class.protected_instance_methods.include?(name)
        super
      else
        mappings = all_mappings

        if mapped_name?(mappings, name)
          define_attribute_methods(mappings)

          send(name, *args, &block)
        else
          super
        end
      end
    end

    # Look for methods that might be dynamically defined and define them for lookup.
    def respond_to_missing?(name, include_private = false)
      # Added magically by Ruby 1.9.3
      if name == :to_ary || name == :empty?
        false
      else
        unless @attribute_methods_defined
          define_attribute_methods(all_mappings)
        end

        mapped_name?(all_mappings, name)
      end
    end

    # Is the name given part of the attribute mappings?
    #
    # @param [Array<FlatMap::Mapping>] mappings
    # @param [String] name
    # @return Boolean
    def mapped_name?(mappings, name)
      valid_names = mappings.map do |mapping|
        full_name = mapping.full_name
        [full_name, "#{full_name}=".to_sym]
      end
      valid_names.flatten!

      valid_names.include?(name)
    end

    # Return the list of all mapped attributes
    #
    # @return [Array<String>]
    def attribute_names
      all_mappings.map { |mapping| mapping.full_name }
    end

    # Actually define the attribute methods on this object.
    #
    # @param [Array<FlatMap::Mapping>] mappings list of mappings
    def define_attribute_methods(mappings)
      extend attribute_methods(mappings)
      @attribute_methods_defined = true
    end
    private :define_attribute_methods

    # Define anonymous module with reader and writer methods for
    # all the +mappings+ being passed.
    #
    # @param [Array<FlatMap::Mapping>] mappings list of mappings
    # @return [Module] module with method definitions
    def attribute_methods(mappings)
      Module.new do
        mappings.each do |mapping|
          full_name = mapping.full_name

          define_method(full_name){ |*args| mapping.read(*args) }

          define_method("#{full_name}=") do |value|
            mapping.write(value)
          end
        end
      end
    end
    private :attribute_methods
  end
end
