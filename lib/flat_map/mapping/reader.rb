module FlatMap
  # Reader module hosts various readers that are used by
  # mappings for reading and returning values.
  module Mapping::Reader
    extend ActiveSupport::Autoload

    autoload :Basic
    autoload :Method
    autoload :Proc
    autoload :Formatted
  end
end
