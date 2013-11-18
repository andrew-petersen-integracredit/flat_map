module FlatMap
  # Writer module hosts various writer classes that are used
  # by mappings to assign values to the target of an associated mapper.
  module Mapping::Writer
    extend ActiveSupport::Autoload

    autoload :Basic
    autoload :Method
    autoload :Proc
  end
end
