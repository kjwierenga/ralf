require 'spec_helper'
require 'ralf'

describe Ralf do

  describe "#read_config_from_file" do
    before do
      File.should_receive(:open).with('./ralf.conf').and_return(StringIO.new('option: value'))
      subject.should_receive(:validate_config).and_return(true)
    end
    it "reads the config" do
      subject.read_config_from_file('./ralf.conf').should be_true
    end
    it "sets the config" do
      subject.read_config_from_file('./ralf.conf')
      subject.config.should eql({:option => "value"})
    end
  end
  describe "#config=" do
    it "symbolizes the keys and validates the options"  do
      subject.should_receive(:validate_config)
      subject.config = {"option" => "value"}
      subject.config.should eql({:option => "value"})
    end
  end
  describe "#validate_config" do
    it "raises InvalidConfig if no config is set" do
      lambda {
        subject.validate_config
      }.should raise_error(Ralf::InvalidConfig, "No config set")
    end
    it "raises InvalidConfig if minimal required options are not set" do
      subject.stub(:config).and_return({})
      lambda {
        subject.validate_config
      }.should raise_error(Ralf::InvalidConfig, "Required options: 'cache_dir', 'output_dir', 'days_to_look_back', 'days_to_ignore', 'aws_key', 'aws_secret', 'log_bucket', 'log_prefix'")
    end
    it "does not raise errors when minimal required options are set" do
      subject.stub(:config).and_return({
        :cache_dir  => './cache',
        :output_dir => './logs/:year/:month/:day',
        :days_to_look_back => 5,
        :days_to_ignore => 2,
        :aws_key    => '--AWS_KEY--',
        :aws_secret => '--AWS_SECTRET--',
        :log_bucket => "logbucket",
        :log_prefix => 'logs/'
      })
      lambda {
        subject.validate_config
      }.should_not raise_error
    end
  end

  describe "#initialize_s3" do
    it "sets @s3" do
      subject.stub(:config).and_return({
        :aws_key    => '--AWS_KEY--',
        :aws_secret => '--AWS_SECTRET--'
      })
      subject.initialize_s3
      subject.s3.should_not be_nil
    end
  end

  describe "#process_log_bucket" do
    it "process configured log_bucket" do
      subject.stub(:config).and_return({:log_bucket => ['berl-log']})
      s3_bucket_mock = mock(RightAws::S3::Bucket)
      subject.stub(:s3).and_return(mock(RightAws::S3, :bucket => s3_bucket_mock))
      processor = mock(Ralf::BucketProcessor)
      processor.should_receive(:process)
      Ralf::BucketProcessor.should_receive(:new).and_return(processor)

      subject.process_log_bucket
    end
  end

end
