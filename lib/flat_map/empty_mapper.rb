module FlatMap
  # +EmptyMapper+ behaves in a very same way as targeted {Mapper Mappers}
  # with only distinction of absence of required target. That makes them
  # a platform for mounting other mappers and placing control structures
  # of business logic.
  #
  # Form more detailed information on what mappers are and their API
  # refer to {Mapper}.
  class EmptyMapper < BaseMapper
    # Initializes +mapper+ with +traits+, which are
    # used to fetch proper list of mounted mappers.
    #
    # @param [*Symbol] traits List of traits
    def initialize(*traits)
      @traits = traits

      if block_given?
        singleton_class.trait :extension, &Proc.new
      end
    end

    # Return +true+ since there's no target.
    #
    # @return [true]
    def save_target
      true
    end
  end
end
