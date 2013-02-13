require 'rubygems'
require 'bundler/setup'

require 'right_aws' # load RightHttpConnection before FakeWeb otherwise we get buggy
require 'fakeweb'

RSpec.configure do |config|
  config.treat_symbols_as_metadata_keys_with_true_values = true
  config.run_all_when_everything_filtered = true
  config.filter_run :focus
  config.order = 'random'
end
