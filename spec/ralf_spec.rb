require File.dirname(__FILE__) + '/spec_helper'

require 'ralf'

describe Ralf do

  before(:each) do
    @default_params = {:config => File.dirname(__FILE__) + '/fixtures/config.yaml'}
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
      @bucket1.should_receive(:logging_info).once.and_return({ :enabled => true })
      @bucket2 = {:name => 'bucket2'}
      @bucket2.should_receive(:logging_info).once.and_return({ :enabled => false })
    end

    it "should find buckets with logging enabled" do
      @ralf.s3.should_receive(:buckets).once.and_return([@bucket1, @bucket2])

      @ralf.find_buckets_with_logging.should  eql([@bucket1, @bucket2])
      @ralf.buckets_with_logging.should       eql([@bucket1])
    end

    it "should save logging to disk" do
      @key1 = {:name => '2010-02-10-00-05-32-ZDRFGTCKUYVJCT'}
      @key2 = {:name => '2010-02-10-00-07-28-EFREUTERGRSGDH'}
      @bucket1.should_receive(:name).once.and_return('media.kerdienstgemist.nl')
      @bucket1.should_receive(:keys).once.and_return([@key1, @key2])
      @ralf.save_logging_to_disk(@bucket1).should eql(true)
    end

  end

end
