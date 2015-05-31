require 'rails/all'

# require 'bundler/setup'
# Bundler.setup

$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require 'pail'

RSpec.configure do |config|
  config.filter_run :focus
  config.run_all_when_everything_filtered = true
end