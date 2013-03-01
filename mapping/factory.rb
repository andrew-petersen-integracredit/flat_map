module Core
  module FlatMap
    # Factory objects store mapping definitions within mapper class and are
    # used eventually to generate mapping objects for a particular mapper.
    class Mapping::Factory
      # Simply store all arguments necessary to create a new mapping for
      # a specific mapper.
      #
      # @param [*Object] args
      def initialize(*args)
        @args = args
      end

      # Return a new mapping, initialized by +mapper+ and <tt>@args</tt>.
      #
      # @param [Core::FlatMap::Mapper] mapper
      # @return [Core::FlatMap::Mapping]
      def create(mapper)
        Mapping.new(mapper, *@args)
      end
    end
  end
end
