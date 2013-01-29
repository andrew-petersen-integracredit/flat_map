module Core
  module FlatMap
    module Mapping::Reader
      module Formatted::Formats
        def i18n_l(value)
          Core::I18n::l(value) if value
        end

        def enum(value)
          value.name if value
        end
      end
    end
  end
end
