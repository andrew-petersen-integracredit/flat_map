module FlatMap
  module Mapping::Reader
    # Hosts various formats that can be applied to values read by mappings
    # for post-processing.
    module Formatted::Formats
      if defined? I18n
        # Pass +value+ to <tt>I18n::l</tt> method
        def i18n_l(value)
          I18n::l(value) if value
        end
      end

      if defined? PowerEnum
        # Return the specified +property+ of a +value+ which
        # is supposed to be an +enum+ record. By default,
        # uses <tt>:name</tt>. However, <tt>:description</tt>
        # might be also useful for UI purposes
        #
        # @param [Object] value
        # @param [Symbol] property
        # @return [Object]
        def enum(value, property = :name)
          value.send(property) if value
        end
      end
    end
  end
end
