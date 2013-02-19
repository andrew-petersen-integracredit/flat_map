module Core
  module FlatMap
    class Mapping::Factory
      # Simply stores all arguments necessary to create a
      # new mapping for a specific mapper
      #
      # @params [*Object] args
      def initialize(*args)
        @args = args
      end

      # Return a new mapping, initialized by +mapper+ and
      # <tt>@args</tt>
      #
      # @param [Core::FlatMap::Mapper] mapper
      # @return [Core::FlatMap::Mapping]
      def create(mapper)
        Mapping.new(mapper, *@args)
      end
    end
  end
end
