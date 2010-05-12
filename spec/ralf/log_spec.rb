require File.dirname(__FILE__) + '/../spec_helper'

require 'ralf'
require 'ralf/log'

describe Ralf::Log do

  it "should initialize properly" do
    key    = mock('key')
    prefix = mock('prefix')
    lambda {
      Ralf::Log.new(key, prefix)
    }.should_not raise_error
  end
  
end
