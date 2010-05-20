require File.dirname(__FILE__) + '/../spec_helper'

require 'ralf'
require 'ralf/bucket'

describe Ralf::Bucket do
  
  before(:all) do
    @s3_mock = mock('S3')
    Ralf::Bucket.s3 = @s3_mock
    
    @valid_logging_info = {
      :enabled      => true,
      :targetbucket => 'targetbucket',
      :targetprefix => 'logs/',
    }
    
    # load example buckets (2 disabled)
    @example_buckets = load_example_bucket_mocks
    @enabled_buckets_count = @example_buckets.size - 2
    
    # make s3_mock return individual buckets
    @s3_mock.should_receive(:bucket).any_number_of_times do |name|
      @example_buckets[name]
    end
    
    # make s3_mock return all buckets
    @s3_mock.should_receive(:buckets).any_number_of_times.and_return(@example_buckets.values)
  end
  
  it "should initialize properly" do
    name = 's3_bucket'
    logging_info = {
      :enabled      => true,
      :targetbucket => 's3_bucket',
      :targetprefix => 'logs/',
    }
    bucket = mock(name)
    bucket.should_receive(:logging_info).and_return(logging_info)
    bucket.should_receive(:name).and_return(name)
    
    lambda {
      Ralf::Bucket.new(bucket)
    }.should_not raise_error
  end
  
  it "should set targetbucket to bucket returned by logging_info" do
    name = 's3_bucket'
    targetbucket_name = 's3_targetbucket'
    logging_info = {
      :enabled      => true,
      :targetbucket => targetbucket_name,
      :targetprefix => 'logs/',
    }
    bucket = mock(name)
    bucket.should_receive(:logging_info).and_return(logging_info)
    bucket.should_receive(:name).and_return(name)
    
    Ralf::Bucket.new(bucket)
  end
  
  it "should support iteration over all buckets" do
    yielded_buckets = []
    Ralf::Bucket.each do |bucket|
      yielded_buckets << bucket
    end
    yielded_buckets.should have(@enabled_buckets_count).items
    yielded_buckets.each { |bucket| bucket.name.should_not be_nil }
  end

  it "should support iteration over specific buckets" do
    yielded_buckets = []
    Ralf::Bucket.each(@example_buckets.keys) do |bucket|
      yielded_buckets << bucket
    end
    yielded_buckets.should have(@enabled_buckets_count).items
    yielded_buckets.each do |bucket|
      bucket.logging_enabled?.should eql(@example_buckets[bucket.name].logging_info[:enabled])
      bucket.targetbucket.should eql(@example_buckets[bucket.name].logging_info[:targetbucket])
      bucket.targetprefix.should eql(@example_buckets[bucket.name].logging_info[:targetprefix])
    end
  end
  
  it "should support iterating over all logs in a bucket" do
    bucket_mock = @example_buckets['test1']
    key1, key2 = mock('key1'), mock('key2')
    keys = [key1, key2]
    bucket_mock.should_receive(:keys).with(:prefix => 'logs/2010-05-17').and_return(keys)

    expected_logs = []
    keys.each do |key|
      log = mock('Log')
      Ralf::Log.should_receive(:new).with(key, @example_buckets['test1'].logging_info[:targetprefix]).and_return(log)
      expected_logs << log
    end

    bucket = Ralf::Bucket.new(bucket_mock)
    
    yielded_logs = []
    bucket.each_log(Date.new(2010,05,17)) do |log|
      yielded_logs << log
    end
    yielded_logs.should have(keys.size).items
    yielded_logs.should eql(expected_logs)
  end
  
end
