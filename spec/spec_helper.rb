require 'rubygems'
require 'bundler/setup'

require 'right_aws' # load RightHttpConnection before FakeWeb otherwise we get buggy
require 'fakeweb'

RSpec.configure do |config|

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
