require 'bundler/setup'

require 'flat_map'
require 'ostruct'
require 'pry'
require 'rspec/its'

require 'simplecov'
SimpleCov.start do
  add_filter '/spec/'
end

RSpec.configure do |config|
  config.treat_symbols_as_metadata_keys_with_true_values = true
end
