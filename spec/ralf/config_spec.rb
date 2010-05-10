require File.dirname(__FILE__) + '/../spec_helper'

require 'ralf'
require 'ralf/config'

describe Ralf::Config do
  
  before(:all) do
    @valid_options = {
      :output_file           => 'my_log.log',
      :aws_access_key_id     => 'my_access_key_id',
      :aws_secret_access_key => 'my_secret_access_key',
    }
    @date = Date.strptime('2010-02-09')
    @bucket = 'my.bucket.org'
  end
  
  it "should initialize properly" do
    config = Ralf::Config.new
  end
  
  it "should raise error when no operation specified (--list or --output-file)" do
    lambda {
      config = Ralf::Config.new
      config.validate!
    }.should raise_error(Ralf::Config::ConfigurationError, '--list or --output-file required')
  end
  
  it "should raise error for missing credentials" do
    ENV['AWS_ACCESS_KEY_ID']     = nil
    ENV['AWS_SECRET_ACCESS_KEY'] = nil
    lambda {
      config = Ralf::Config.new(:list => true)
      config.validate!
    }.should raise_error(Ralf::Config::ConfigurationError, 'aws_access_key_id missing, aws_secret_access_key missing')
  end
  
  it "should handle range assignment" do
    config = Ralf::Config.new(@valid_options)
    config.range = 'today'
    puts config.range
  end
  
  it "should interpolate date (:year, :month, :day) variables in output_file" do
    config = Ralf::Config.new(@valid_options.merge(:output_file => ':year/:month/access.log'))
    config.output_file(@date).should eql('2010/02/access.log')
  end

  it "should interpolate :bucket variable in output_file" do
    config = Ralf::Config.new(@valid_options.merge(:output_file => ':bucket.log'))
    config.output_file(@date, @bucket).should eql('my.bucket.org.log')
  end
  
  it "should interpolate variables in cache_dir" do
    config = Ralf::Config.new(@valid_options.merge(:cache_dir => ':year/:month/:bucket'))
    config.cache_dir(@date, @bucket).should eql('2010/02/my.bucket.org')
  end
  
end
