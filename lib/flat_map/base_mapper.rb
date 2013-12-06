module FlatMap
  # +BaseMapper+ is an abstract class that hosts overwhelming majority
  # of common functionality of {EmptyMapper EmptyMappers} and {Mapper Mappers}.
  #
  # For more detailed information on what mappers are, refer to {Mapper} documentation.
  class BaseMapper
    extend ActiveSupport::Autoload

    autoload :Mapping
    autoload :Mounting
    autoload :Traits
    autoload :Factory
    autoload :AttributeMethods
    autoload :Persistence
    autoload :Skipping

    include Mapping
    include Mounting
    include Traits
    include AttributeMethods
    include ActiveModel::Validations
    include Persistence
    include Skipping

    attr_reader :traits
    attr_writer :host, :suffix
    attr_accessor :owner, :name

    # Callback to dup mappings and mountings on inheritance.
    # The values are cloned from actual mappers (i.e. something
    # like CustomerAccountMapper, since it is useless to clone
    # empty values of FlatMap::Mapper).
    #
    # Note: those class attributes are defined in {Mapping}
    # and {Mounting} modules.
    def self.inherited(subclass)
      return unless self < FlatMap::Mapper
      subclass.mappings  = mappings.dup
      subclass.mountings = mountings.dup
    end

    # Raise exception on trying to initialize an instance.
    #
    # @raise [RuntimeError]
    def initialize
      raise 'BaseMapper is abstract class and cannot be initialized'
    end

    # Return a simple string representation of +mapper+. Done so to
    # avoid really long inspection of internal objects (target -
    # usually AR model, mountings and mappings)
    # @return [String]
    def inspect
      to_s
    end

    # Return +true+ if +mapper+ is owned. This means that current
    # mapper is actually a trait. Thus, it is a part of an owner
    # mapper.
    #
    # @return [Boolean]
    def owned?
      owner.present?
    end

    # If mapper was mounted by another mapper, host is the one who
    # mounted +self+.
    #
    # @return [FlatMap::Mapper]
    def host
      owned? ? owner.host : @host
    end

    # Return +true+ if mapper is hosted, i.e. it is mounted by another
    # mapper.
    #
    # @return [Boolean]
    def hosted?
      host.present?
    end

    # +suffix+ reader. Delegated to owner for owned mappers.
    #
    # @return [String, nil]
    def suffix
      owned? ? owner.suffix : @suffix
    end

    # Return +true+ if +suffix+ is present.
    #
    # @return [Boolean]
    def suffixed?
      suffix.present?
    end
  end
end
