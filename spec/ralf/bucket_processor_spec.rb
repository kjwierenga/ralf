require 'spec_helper'
require 'ralf'

describe Ralf::BucketProcessor do

  before do
    @s3_bucket_mock = mock(RightAws::S3::Bucket, :name => "logfilebucket")
    @ralf = mock(Ralf, :config => {
      :cache_dir  => './logs/cache/:bucket',
      :output_dir => './logs/:bucket/:year/:month/:day.log',
      :log_prefix => 'logs/',
      :days_to_look_back => 3,
      :days_to_ignore => 1,
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
    describe "#process_keys_for_range" do
      it "retrieve the keys in the range" do
        Date.stub(:today).and_return(Date.new(2013, 2, 13))
        subject.should_receive(:process_keys_for_date).with(Date.new(2013, 2, 11))
        subject.should_receive(:process_keys_for_date).with(Date.new(2013, 2, 12))
        subject.should_receive(:process_keys_for_date).with(Date.new(2013, 2, 13))
        subject.process_keys_for_range
      end
    end
    describe "#process_keys_for_date" do
      it "finds all keys for date" do
        key_mock1 = mock(RightAws::S3::Key, :name => 'logs/2013-02-11-00-05-23-UYVJCTKCTGFRDZ')
        key_mock2 = mock(RightAws::S3::Key, :name => 'logs/2013-02-12-00-23-05-CVJCTZDRFGTYUK')
        key_mock3 = mock(RightAws::S3::Key, :name => 'logs/2013-02-13-05-00-23-FGTCCJVYUKTRDZ')
        @s3_bucket_mock.should_receive(:keys).with({"prefix"=>"logs/2013-02-13"}).and_return([key_mock1, key_mock2, key_mock3])
        subject.should_receive(:download_key).with(key_mock1)
        subject.should_receive(:download_key).with(key_mock2)
        subject.should_receive(:download_key).with(key_mock3)
        subject.process_keys_for_date(Date.new(2013, 2, 13))
      end
      it "should return an array of filenames"
    end
    describe "#download_key" do
      before do
        @key_mock1 = mock(RightAws::S3::Key, :name => 'logs/2013-02-11-00-05-23-UYVJCTKCTGFRDZ', :data => 'AWS LOGLINE')
        subject.should_receive(:cache_dir).and_return('./logs/cache/logfilebucket/')
      end
      it "downloads key if it does not exists" do
        File.should_receive(:exist?).with('./logs/cache/logfilebucket/2013-02-11-00-05-23-UYVJCTKCTGFRDZ').and_return(false)
        File.should_receive(:open).with("./logs/cache/logfilebucket/2013-02-11-00-05-23-UYVJCTKCTGFRDZ", "w").and_yield(mock(File, :write => true))
        subject.download_key(@key_mock1)
      end
      it "skip download for key if it already exists in cache" do
        File.should_receive(:exist?).with('./logs/cache/logfilebucket/2013-02-11-00-05-23-UYVJCTKCTGFRDZ').and_return(true)
        File.should_not_receive(:open)
        subject.download_key(@key_mock1)
      end
    end
    describe "#merge" do
      it "reads all files from range into memory and sort it by timestamp" do
        subject.merge([
          'spec/fixtures/2012-06-04-17-15-58-41BB059FD94A4EC7',
          'spec/fixtures/2012-06-04-17-16-40-4E34CC5FF2B57639'
        ]).collect {|l| l[:timestamp].to_s}.should eql([
          "2012-06-03T16:34:26+00:00",
          "2012-06-03T16:34:26+00:00",
          "2012-06-04T16:34:28+00:00",
          "2012-06-04T16:44:26+00:00",
          "2012-06-04T16:44:26+00:00",
          "2012-06-04T16:45:41+00:00",
          "2012-06-04T16:46:31+00:00",
          "2012-06-04T16:46:31+00:00",
          "2012-06-05T16:36:31+02:00",
          "2012-06-05T16:35:41+00:00",
        ])
      end
    end
    describe "#write_to_combined" do
      it "writes to combined files in the subirectories" do
        subject.stub(:ensure_output_directories).and_return(true)
        subject.stub(:open_file_descriptors).and_return(true)
        subject.stub(:close_file_descriptors).and_return(true)

        open_file_11 = StringIO.new
        open_file_12 = StringIO.new
        open_file_13 = StringIO.new
        subject.stub(:open_files).and_return({2013 => {2 =>{
          12 => open_file_12,
          13 => open_file_13
        }}})
        open_file_12.should_receive(:puts).twice.and_return(true)
        open_file_13.should_receive(:puts).and_return(true)

        subject.write_to_combined([
          {:timestamp => Time.mktime(2013, 2, 11, 16, 34, 26, '+0000').utc   , :string => 'logfile_string'},
          {:timestamp => Time.mktime(2013, 2, 12, 16, 34, 26, '+0000').utc+10, :string => 'logfile_string'},
          {:timestamp => Time.mktime(2013, 2, 12, 16, 34, 26, '+0000').utc+15, :string => 'logfile_string'},
          {:timestamp => Time.mktime(2013, 2, 13, 16, 34, 26, '+0000').utc+23, :string => 'logfile_string'}
        ])
      end
    end
    describe "#ensure_output_directories" do
      it "ensures that base dir exists" do
        FileUtils.should_receive(:mkdir_p).with('./logs/logfilebucket/2013/02')
        subject.ensure_output_directories([Date.new(2013, 2, 13)])
      end
    end
    describe "#open_file_descriptors" do
      it "opens filedescriptors" do
        File.should_receive(:open).with('./logs/logfilebucket/2013/02/13.log', 'w')
        subject.open_file_descriptors([Date.new(2013, 2, 13)])
      end
    end
    describe "#close_file_descriptors" do
      it "closes filedescriptors" do
        open_file = StringIO.new
        subject.stub(:open_files).and_return({2013 => {2 =>{13 => open_file}}})
        open_file.should_receive(:close).and_return(true)
        subject.close_file_descriptors
      end
    end
    describe "#cache_dir" do
      it "interpolates the cache_dir" do
        File.should_receive(:exist?).with('cache/logfilebucket').and_return(true)
        subject.should_receive(:config).and_return({:cache_dir => 'cache/:bucket'})
        subject.cache_dir.should eql('cache/logfilebucket')
      end
      it "raises error if cache_dir does not exists" do
        lambda {
          subject.cache_dir
        }.should raise_error(Ralf::InvalidConfig, "Required options: 'Cache dir does not exixst'")
      end
    end
  end
end

