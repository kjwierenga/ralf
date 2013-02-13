require 'spec_helper'
require 'ralf'

describe Ralf::BucketProcessor do

  before do
    @s3_bucket_mock = mock(RightAws::S3::Bucket)
    @ralf = mock(Ralf, :config => {
      :cache_dir  => './cache',
      :output_dir => './logs/:year/:month/:day',
      :log_prefix => 'logs/',
      :range_size => 2,
      :recalculate_partial_content => true
    })
  end

  describe "#initialize" do
    it "needs an S3 bucket and a config hash" do
      lambda {
        Ralf::BucketProcessor.new(@s3_bucket_mock, @ralf)
      }.should_not raise_error
    end
  end

  describe "with an initalized object" do
    subject { Ralf::BucketProcessor.new(@s3_bucket_mock, @ralf) }
    describe "#collected_files" do
      it "retrieve the keys in the range" do
        Date.stub(:today).and_return(Date.new(2013, 2, 13))
        subject.should_receive(:process_keys_for_date).with(Date.new(2013, 2, 11))
        subject.should_receive(:process_keys_for_date).with(Date.new(2013, 2, 12))
        subject.should_receive(:process_keys_for_date).with(Date.new(2013, 2, 13))
        subject.collected_files
      end
    end
    describe "#process_keys_for_date" do
      it "finds all keys for date" do
        key_mock1 = mock(RightAws::S3::Key, :name => 'logs/2013-02-11-00-05-23-UYVJCTKCTGFRDZ')
        key_mock2 = mock(RightAws::S3::Key, :name => 'logs/2013-02-12-00-23-05-CVJCTZDRFGTYUK')
        key_mock3 = mock(RightAws::S3::Key, :name => 'logs/2013-02-13-05-00-23-FGTCCJVYUKTRDZ')
        @s3_bucket_mock.should_receive(:keys).with({"prefix"=>"logs/2013-02-13"}).and_return([key_mock1, key_mock2, key_mock3])
        subject.should_receive(:download).with(key_mock1)
        subject.should_receive(:download).with(key_mock2)
        subject.should_receive(:download).with(key_mock3)
        subject.process_keys_for_date(Date.new(2013, 2, 13))
      end
      it "should return an array of filenames"
    end
    describe "#download" do
      before do
        @key_mock1 = mock(RightAws::S3::Key, :name => 'logs/2013-02-11-00-05-23-UYVJCTKCTGFRDZ', :data => 'AWS LOGLINE')
      end
      it "downloads key if it does not exists" do
        File.should_receive(:exist?).and_return(false)
        File.should_receive(:open).with("./cache/2013-02-11-00-05-23-UYVJCTKCTGFRDZ", "w").and_yield(mock(File, :write => true))
        subject.download(@key_mock1)
      end
      it "skip download for key if it already exists in cache" do
        File.should_receive(:exist?).and_return(true)
        File.should_not_receive(:open)
        subject.download(@key_mock1)
      end
    end
    describe "#merge" do
      it "reads all files from range into memory and sort it by timestamp" do
        subject.merge([
          'spec/fixtures/2012-06-04-17-15-58-41BB059FD94A4EC7',
          'spec/fixtures/2012-06-04-17-16-40-4E34CC5FF2B57639'
        ]).collect {|l| l.timestamp.to_s}.should eql(["04/Jun/2012:16:34:26 +0000", "04/Jun/2012:16:34:26 +0000", "04/Jun/2012:16:34:26 +0000", "04/Jun/2012:16:34:26 +0000", "04/Jun/2012:16:34:26 +0000", "04/Jun/2012:16:35:41 +0000", "04/Jun/2012:16:35:41 +0000", "04/Jun/2012:16:36:31 +0000", "04/Jun/2012:16:36:31 +0000", "04/Jun/2012:16:36:31 +0000"])
      end
    end

  end
end

