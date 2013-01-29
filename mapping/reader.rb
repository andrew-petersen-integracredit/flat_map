module Core
  module FlatMap
    module Mapping::Reader
      extend ActiveSupport::Autoload

      autoload :Basic
      autoload :Method
      autoload :Proc
      autoload :Formatted
    end
  end
end
