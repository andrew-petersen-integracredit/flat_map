source "https://rubygems.org"

# Specify your gem's dependencies in flat_map.gemspec
gemspec

group :development do
  gem 'redcarpet'
  gem 'yard'
  gem 'pry'

  gem 'gemfury', :require => false
end

group :development, :test do
  # code metrics:
  gem "metric_fu"
end

group :test do
  gem 'simplecov'          , :require => false
  gem 'simplecov-rcov-text', :require => false
end
