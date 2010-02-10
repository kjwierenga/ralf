require File.dirname(__FILE__) + '/spec_helper'

require 'ralf'

describe Ralf do

  before(:each) do
    @default_params = {:config => File.dirname(__FILE__) + '/fixtures/config.yaml', :date => '2010-02-10'}
  end

  it "should initialize properly" do
    ralf = Ralf.new(@default_params)
    ralf.class.should eql(Ralf)
  end

  describe "Preferences" do

    it "should raise an error when an nonexistent config file is given" do
      lambda {
        ralf = Ralf.new(:config => '~/a_non_existen_file.yaml')
      }.should  raise_error(Ralf::NoConfigFile)
    end

    it "should set the preferences" do
      ralf = Ralf.new(@default_params)
      ralf.config[:aws_access_key_id].should      eql('access_key')
      ralf.config[:aws_secret_access_key].should  eql('secret')
      ralf.config[:out_path].should               eql('/Users/berl/S3')
      # ralf.config.should eql({:aws_access_key_id => 'access_key', :aws_secret_access_key => 'secret'})
    end

  end

  describe "Date handling" do

    it "should set the date to today" do
      ralf = Ralf.new(@default_params)
      date = Date.today
      ralf.date.should  eql("%4d-%02d-%02d" % [date.year, date.month, date.day])
    end

    it "should set the date to the date given" do
      ralf = Ralf.new(@default_params.merge(:date => '2010-02-01'))
      ralf.date.should  eql('2010-02-01')
    end

    it "should raise error when invalid date given" do
      lambda {
        ralf = Ralf.new(@default_params.merge(:date => 'now'))
        ralf.date.should  be_nil
      }.should raise_error(ArgumentError, "invalid date")
    end

  end

  describe "Handle Buckets" do

    before(:each) do
      @ralf = Ralf.new(@default_params)
      @bucket1 = {:name => 'bucket1'}
      @bucket1.should_receive(:logging_info).any_number_of_times.and_return({ :enabled => true, :targetprefix => "log/" })
      @bucket2 = {:name => 'bucket2'}
      @bucket2.should_receive(:logging_info).any_number_of_times.and_return({ :enabled => false, :targetprefix => "log/" })
      @bucket1.should_receive(:name).any_number_of_times.and_return('media.kerdienstgemist.nl')
    end

    it "should find buckets with logging enabled" do
      @ralf.s3.should_receive(:buckets).once.and_return([@bucket1, @bucket2])

      @ralf.find_buckets_with_logging.should  eql([@bucket1, @bucket2])
      @ralf.buckets_with_logging.should       eql([@bucket1])
    end

    it "should save logging to disk" do
      @key1 = {:name => 'log/2010-02-10-00-05-32-ZDRFGTCKUYVJCT', :data => 'This is content'}
      @key2 = {:name => 'log/2010-02-10-00-07-28-EFREUTERGRSGDH', :data => 'This is content'}
      @bucket1.should_receive(:keys).any_number_of_times.and_return([@key1, @key2])
      @key1.should_receive(:name).any_number_of_times.and_return(@key1[:name])
      @key2.should_receive(:name).any_number_of_times.and_return(@key2[:name])
      @key1.should_receive(:data).any_number_of_times.and_return(@key1[:data])
      @key2.should_receive(:data).any_number_of_times.and_return(@key2[:data])
      File.should_receive(:makedirs).twice.and_return(true)
      File.should_receive(:exists?).twice.and_return(false, true)
      File.should_receive(:open).once.and_return(true)

      @ralf.save_logging_to_disk(@bucket1).should eql([@key1, @key2])
    end

    it "should merge all logs" do
      Dir.should_receive(:glob).with('/Users/berl/S3/media.kerdienstgemist.nl/log/2010-02-10*').and_return(
          ['/Users/berl/S3/media.kerdienstgemist.nl/log/2010-02-10-00-05-32-ZDRFGTCKUYVJCT',
           '/Users/berl/S3/media.kerdienstgemist.nl/log/2010-02-10-00-07-28-EFREUTERGRSGDH'])
      File.should_receive(:open).with('/Users/berl/S3/s3_combined_media.kerdienstgemist.nl_2010-02-10.alf', "w").and_return(File)
      LogMerge::Merger.should_receive(:merge).with(
        File, 
        '/Users/berl/S3/media.kerdienstgemist.nl/log/2010-02-10-00-05-32-ZDRFGTCKUYVJCT',
        '/Users/berl/S3/media.kerdienstgemist.nl/log/2010-02-10-00-07-28-EFREUTERGRSGDH'
      ).and_return(true)
      @ralf.merge_to_combined(@bucket1)
    end

  end

end
