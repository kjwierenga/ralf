require 'rubygems'
require 'spork'
require 'right_aws' # load RightHttpConnection before FakeWeb otherwise we get buggy
require 'fakeweb'

Spork.prefork do

  require 'spec/autorun'

  Spec::Runner.configure do |config|
    # == Notes
    #
    # For more information take a look at Spec::Runner::Configuration and Spec::Runner
  end
end

Spork.each_run do

  Dir[File.expand_path(File.join(File.dirname(__FILE__),'support','**','*.rb'))].each {|f| require f }

  Spec::Runner.configure do |config|
    # config.before(:each) { Sham.reset }
  end
end
