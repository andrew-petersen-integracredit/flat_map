module FlatMap
  # This helper module slightly enhances functionality of the
  # {BaseMapper::Skipping} module for most commonly used +ActiveRecord+ targets.
  # This is done to improve modularity of the {FlatMap} mappers.
  module Mapper::Skipping
    # Extend original #skip! method for Rails-models-based targets
    #
    # Note that this will mark the target record as
    # destroyed if it is a new record. Thus, this
    # record will not be a subject of Rails associated
    # validation procedures, and will not be saved as an
    # associated record.
    #
    # @return [Object]
    def skip!
      super
      if target.is_a?(ActiveRecord::Base)
        if target.new_record?
          # Using the instance variable directly as {ActiveRecord::Base#delete}
          # will freeze the record.
          target.instance_variable_set('@destroyed', true)
        else
          # Using reload instead of reset_changes! to reset associated nested
          # model changes also
          target.reload
        end
      end
    end

    # Extend original #use! method for Rails-models-based targets, as
    # acoompanied to #skip! method.
    #
    # @return [Object]
    def use!
      super
      if target.is_a?(ActiveRecord::Base)
        if target.new_record?
          target.instance_variable_set('@destroyed', false) 
        else
          all_nested_mountings.each(&:use!)
        end
      end
    end
  end
end
