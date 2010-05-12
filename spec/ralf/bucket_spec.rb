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
    
    # @s3_mock.should_receive(:bucket).with(name).and_return(mock('targetbucket'))
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
    
    @s3_mock.should_receive(:bucket).with(targetbucket_name).and_return(mock('s3_targetbucket'))
    Ralf::Bucket.new(bucket)
  end
  
end
