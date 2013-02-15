module Core
  module FlatMap
    class Mapping
      extend ActiveSupport::Autoload

      autoload :Reader
      autoload :Writer
      autoload :Factory

      attr_reader :mapper, :name, :target_attribute
      attr_reader :reader, :writer
      attr_reader :multiparam

      delegate :target, :to => :mapper
      delegate :write,  :to => :writer, :allow_nil => true
      delegate :read,   :to => :reader, :allow_nil => true

      def initialize(*args)
        @mapper, @name, @target_attribute, options = args
        @multiparam = options[:multiparam]

        fetch_reader(options)
        fetch_writer(options)
      end

      def multiparam?
        !!@multiparam
      end

      def write_from_params(params)
        write(params[name]) if params.key?(name) && writer.present?
      end

      def read_as_params
        reader ? {name => read} : {}
      end

      def fetch_reader(options)
        klass = 
          case options[:reader]
          when Symbol, String
            Reader::Method
          when Proc
            Reader::Proc
          when false
            @reader = nil
          else
            options.key?(:format) ? Reader::Formatted : Reader::Basic
          end
        @reader = klass.new(self, options) unless defined? @reader
      end

      def fetch_writer(options)
        klass =
          case options[:writer]
          when Symbol, String
            Writer::Method
          when Proc
            Writer::Proc
          when false
            @writer = false
          else
            Writer::Basic
          end

        @writer = klass.new(self, options[:writer]) unless defined? @writer
      end
    end
  end
end
