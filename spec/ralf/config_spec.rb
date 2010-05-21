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
    }.merge(@aws_credentials)

    @date = Date.strptime('2010-02-09')
    @bucket = 'my.bucket.org'
  end
  
  it "should initialize properly" do
    config = Ralf::Config.new
  end
  
  it "should raise error for missing credentials" do
    lambda {
      config = Ralf::Config.new
      config.validate!
    }.should raise_error(Ralf::Config::ConfigurationError, 'aws_access_key_id missing, aws_secret_access_key missing')
  end
  
  it "should handle range assignment" do
    now = Time.now
    yesterday = Date.today - 1
    Time.should_receive(:now).any_number_of_times.and_return(now)
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
  
  it "should allow 'this month' with base 'yesterday'" do
    Time.should_receive(:now).any_number_of_times.and_return(Time.parse('Sat May 01 16:31:00 +0100 2010'))
    config = Ralf::Config.new(:range => 'this month', :now => 'yesterday')
    config.range.to_s.should eql('2010-04-01..2010-04-30')
  end
  
  it "should merge options" do
    Time.should_receive(:now).any_number_of_times.and_return(Time.parse('Sat May 01 16:31:00 +0100 2010'))
    config = Ralf::Config.new
    config.merge!(:range => 'this month', :now => 'yesterday')
    config.range.to_s.should eql('2010-04-01..2010-04-30')
  end
  
  it "should support setting now after range and recompute range" do
    Time.should_receive(:now).any_number_of_times.and_return(Time.parse('Sat May 01 16:31:00 +0100 2010'))
    config = Ralf::Config.new
    config.merge!(:range => 'this month')
    config.merge!(:now => 'yesterday')
    config.range.to_s.should eql('2010-04-01..2010-04-30')
  end
  
  it "should support setting range first then change now (1st day of month)" do
    Time.should_receive(:now).any_number_of_times.and_return(Time.parse('Sat May 01 16:31:00 +0100 2010'))
    config = Ralf::Config.new
    config.merge!(:range => 'this month')
    config.range.to_s.should eql('2010-05-01..2010-05-01')
    config.merge!(:now => 'yesterday')
    config.range.to_s.should eql('2010-04-01..2010-04-30')
  end
  
  it "should support setting range first then change now" do
    Time.should_receive(:now).any_number_of_times.and_return(Time.parse('Sat May 08 16:31:00 +0100 2010'))
    config = Ralf::Config.new
    config.merge!(:range => 'this month')
    config.range.to_s.should eql('2010-05-01..2010-05-07')
    config.merge!(:now => '2010-05-06')
    config.range.to_s.should eql('2010-05-01..2010-05-06')
  end
  
  it "should set default cache_dir to '/var/log/ralf/:bucket' when running as root" do
    Process.should_receive(:uid).and_return(0)
    config = Ralf::Config.new
    config.cache_dir_format.should eql('/var/log/ralf/:bucket')
  end
  
  it "should set default cache_dir to '~/.ralf/:bucket' when running as regular user" do
    Process.should_receive(:uid).and_return(1)
    File.should_receive(:expand_path).with('~/.ralf/:bucket').and_return('/Users/me/.ralf/:bucket')
    config = Ralf::Config.new
    config.cache_dir_format.should eql('/Users/me/.ralf/:bucket')
  end
  
  it "should allow overriding bucket with merge!" do
    config = Ralf::Config.new(:buckets => ['bucket1', 'bucket2'])
    config.buckets = ['bucket3']
    config.buckets.should eql(['bucket3'])
  end
  
  it "should load configuration from file" do
    YAML.should_receive(:load_file).with('my_config.yaml').and_return(@valid_options)
    config = Ralf::Config.load_file('my_config.yaml')
    config.output_file_format.should eql(@valid_options[:output_file])
  end
  
  it "should warn and continue (not raise exception) when unknown configuration variables are set" do
    $stdout = StringIO.new
    lambda {
      config = Ralf::Config.new(:unknown_variable => 100)
    }.should_not raise_error
    $stdout.string.should eql("Warning: invalid configuration variable: unknown_variable\n")
  end

end
