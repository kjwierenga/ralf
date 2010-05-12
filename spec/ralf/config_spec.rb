require File.dirname(__FILE__) + '/../spec_helper'

require 'ralf'
require 'ralf/config'

describe Ralf::Config do
  
  before(:all) do
    ENV['AWS_ACCESS_KEY_ID'], ENV['AWS_SECRET_ACCESS_KEY'] = nil, nil
    
    @aws_credentials = {
      :aws_access_key_id     => 'access_key_id',
      :aws_secret_access_key => 'secret_key',
    }
    
    @valid_options = {
      :output_file           => 'my_log.log',
      :aws_access_key_id     => 'my_access_key_id',
      :aws_secret_access_key => 'my_secret_access_key',
    }.merge(@aws_credentials)
    @date = Date.strptime('2010-02-09')
    @bucket = 'my.bucket.org'
  end
  
  it "should initialize properly" do
    config = Ralf::Config.new
  end
  
  it "should raise error for missing credentials" do
    lambda {
      config = Ralf::Config.new(:list => true)
      config.validate!
    }.should raise_error(Ralf::Config::ConfigurationError, 'aws_access_key_id missing, aws_secret_access_key missing')
  end
  
  it "should handle range assignment" do
    now = Time.now
    yesterday = Date.today - 1
    Time.should_receive(:now).twice.and_return(now)
    config = Ralf::Config.new(@valid_options)
    config.range = 'yesterday'
    config.range.should eql(Range.new(yesterday, yesterday))
  end
  
  it "should interpolate date (:year, :month, :day) variables in output_file" do
    config = Ralf::Config.new(@valid_options.merge(:output_file => ':year/:month/access.log'))
    config.output_file(:date => @date).should eql('2010/02/access.log')
  end

  it "should interpolate :bucket variable in output_file" do
    config = Ralf::Config.new(@valid_options.merge(:output_file => ':bucket.log'))
    config.output_file(:date => @date, :bucket => @bucket).should eql('my.bucket.org.log')
  end
  
  it "should interpolate variables in cache_dir" do
    config = Ralf::Config.new(@valid_options.merge(:cache_dir => ':year/:month/:bucket'))
    config.cache_dir(:date => @date, :bucket => @bucket).should eql('2010/02/my.bucket.org')
  end
  
end
