require 'rubygems'
require 'right_aws' # load RightHttpConnection before FakeWeb otherwise we get buggy
require 'fakeweb'

require 'spec/autorun'

Spec::Runner.configure do |config|
  # == Notes
  #
  # For more information take a look at Spec::Runner::Configuration and Spec::Runner
  
  def load_example_bucket_mocks
    buckets = YAML.load(File.open(File.join(File.dirname(__FILE__), 'fixtures', 'example_buckets.yaml')))
    buckets = buckets.inject({}) do |memo, info|
      info[:keys].map! do |key|
        mock(key[:name], key)
      end
      memo.merge!(info[:name] => mock(info[:name], info))
      memo
    end
    buckets
  end
end

