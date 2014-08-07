require 'ostruct'
require 'active_support'
require 'active_record'

require "flat_map/version"
require 'flat_map/mapping'
require 'flat_map/errors'
require 'flat_map/open_mapper'
require 'flat_map/model_mapper'

module FlatMap
  # for backwards compatability
  Mapper = ModelMapper
end
