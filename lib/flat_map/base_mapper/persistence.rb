module FlatMap
  # This module provides persistence functionality for mappers. Note
  # that term of persistence here does not imply storing information
  # in database or other place. This module provides methods for
  # saving operation as a work flow of applying parameters to mapper
  # and all of its mounted mappers in a right way, running callbacks,
  # etc.
  #
  # See {Mapper::Targeting} for a place where mapper targets are
  # actually get persisted / updated.
  #
  # In particular, validation and save methods are defined here. And
  # the <tt>save</tt> method itself is defined as a callback. Also, Rails
  # multiparam attributes extraction is defined within this module.
  module BaseMapper::Persistence
    # Write a passed set of +params+. Then try to save the model if +self+
    # passes validation. Saving is performed in a transaction.
    #
    # @param [Hash] params
    # @return [Boolean]
    def apply(params)
      write(params)
      valid? && save
    end

    # Extract the multiparam values from the passed +params+. Then use the
    # resulting hash to assign values to the target. Assignment is performed
    # by sending writer methods to +self+ that correspond to keys in the
    # resulting +params+ hash.
    #
    # @param [Hash] params
    # @return [Hash] params
    def write(params)
      extract_multiparams!(params)

      params.each do |name, value|
        self.send("#{name}=", value)
      end
    end

    # Try to save the target and send a +save+ method to all mounted mappers.
    #
    # The order in which mappings are saved is important, since we save
    # records with :validate => false option. Since Rails will perform
    # auto-saving on associations (and it in its turn will try to save associated
    # record with :validate => true option. To be more precise, with
    # :validate => !autosave option, where autosave corresponds to that option
    # of reflection, which is usually not specified, i.e. nil), we might come to
    # a situation of saving a record with nil foreign key for belongs_to association,
    # which will raise exception. Thus, we want to explicitly save records in
    # order which will allow them to be saved.
    # Return +false+ if that chain of +save+ calls returns +true+ on any of
    # its elements. Return +true+ otherwise.
    #
    # Saving is performed as a callback.
    #
    # @return [Boolean]
    def save
      before_res = save_mountings(before_save_mountings)
      target_res = self_mountings.map{ |m| m.shallow_save }.all?
      after_res  = save_mountings(after_save_mountings)

      before_res && target_res && after_res
    end

    # Perform target save with callbacks call
    #
    # @return [Boolean]
    def shallow_save
      run_callbacks(:save){ save_target }
    end

    # Send <tt>:save</tt> method to all mountings in list. Will return +true+
    # only if all savings are positive.
    #
    # @param [Array<FlatMap::BaseMapper>] mountings
    # @return [Boolean]
    def save_mountings(mountings)
      mountings.map{ |mount| mount.save }.all?
    end
    private :save_mountings

    # Return +true+ if the mapper is valid, i.e. if it is valid itself, and if
    # all mounted mappers (traits and other mappers) are also valid.
    #
    # Accepts any parameters, but doesn't use them to be compatible with
    # ActiveRecord calls.
    #
    # @return [Boolean]
    def valid?(*)
      res = trait_mountings.map(&:valid?).all?
      res = super && res # we do want to call super
      mounting_res = mapper_mountings.map(&:valid?).all?
      consolidate_errors!
      res && mounting_res
    end

    # Consolidate the errors of all mounted mappers to a set of errors of +self+.
    #
    # @return [Array<ActiveModel::Errors>]
    def consolidate_errors!
      mountings.map(&:errors).each do |errs|
        errors.messages.merge!(errs.to_hash){ |k, old, new| old.concat(new) }
      end
    end
    private :consolidate_errors!

    # Overridden to use {FlatMap::Errors} instead of ActiveModel ones.
    #
    # @return [FlatMap::Errors]
    def errors
      @errors ||= FlatMap::Errors.new(self)
    end

    # Extract Rails multiparam parameters from the +params+, modifying
    # original hash. Behaves somewhat like
    # {ActiveRecord::AttributeAssignment#extract_callstack_for_multiparameter_attributes}
    # See this method for more details.
    #
    # @param [Hash] params
    # @return [Array<FlatMap::Mapping>] return value is not used, original
    #   +params+ hash is modified instead and used later on.
    def extract_multiparams!(params)
      all_mappings.select(&:multiparam?).each do |mapping|
        param_keys = params.keys.
          select{ |k| k.to_s =~ /#{mapping.full_name}\(\d+[isf]\)/ }.
          sort_by{ |k| k.to_s[/\((\d+)\w*\)/, 1].to_i }

        next if param_keys.empty?

        args = param_keys.inject([]) do |values, key|
          value = params.delete key
          type  = key[/\(\d+(\w*)\)/, 1]
          value = value.send("to_#{type}") unless type.blank?

          values.push value
          values
        end

        params[mapping.name] = mapping.multiparam.new(*args) rescue nil
      end
    end
    private :extract_multiparams!
  end
end
