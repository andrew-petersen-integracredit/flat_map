module Core
  module FlatMap
    module Mapper::ReaderMethods
      def method_missing(name, *args, &block)
        return super if @reader_methods_defined

        mappings = all_mappings

        return super unless mappings.map(&:name).include?(name)

        extend reader_methods(mappings)
        @reader_methods_defined = true
        send(name)
      end

      def reader_methods(mappings)
        Module.new do
          mappings.each do |mapping|
            define_method(mapping.name){ mapping.read }
          end
        end
      end
      private :reader_methods
    end
  end
end
