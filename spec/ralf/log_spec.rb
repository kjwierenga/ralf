require File.dirname(__FILE__) + '/../spec_helper'

require 'ralf'
require 'ralf/log'

describe Ralf::Log do

  it "should initialize properly" do
    key    = mock('key')
    prefix = mock('prefix')
    lambda {
      Ralf::Log.new(key, prefix)
    }.should_not raise_error
  end
  
  it "should remove prefix when returing name" do
    key = mock('key', :name => 'log/access_log-2010-02-10-00-05-32-ZDRFGTCKUYVJCT')
    log = Ralf::Log.new(key, 'log/access_log-')
    log.name.should eql('2010-02-10-00-05-32-ZDRFGTCKUYVJCT')
  end
  
  it "should save specified file to dir" do
    key = mock('key', :name => 'log/access_log-2010-02-10-00-05-32-ZDRFGTCKUYVJCT')
    log = Ralf::Log.new(key, 'log/access_log-')

    dir      = '/var/log/s3'
    filename = File.join(dir, log.name)
    fileio   = mock('File')
    key.should_receive(:data).and_return('testdata')
    File.should_receive(:open).with(filename, 'w').and_yield(fileio)
    File.should_receive(:exist?).with(filename).and_return(false)
    fileio.should_receive(:write).with('testdata')
    log.save_to_dir(dir)
  end
  
  it "should not save file if it exists and caching enabled (default)" do
    key = mock('key', :name => 'log/access_log-2010-02-10-00-05-32-ZDRFGTCKUYVJCT')
    log = Ralf::Log.new(key, 'log/access_log-')

    dir      = '/var/log/s3'
    filename = File.join(dir, log.name)
    fileio   = mock('File')
    File.should_receive(:exist?).with(filename).and_return(true)
    File.should_not_receive(:open).with(filename, 'w')
    log.save_to_dir(dir)
  end
  
  it "should not check file if use_cache = false" do
    key = mock('key', :name => 'log/access_log-2010-02-10-00-05-32-ZDRFGTCKUYVJCT')
    log = Ralf::Log.new(key, 'log/access_log-')

    dir      = '/var/log/s3'
    filename = File.join(dir, log.name)
    fileio   = mock('File')

    key.should_receive(:data).and_return('testdata')
    File.should_receive(:open).with(filename, 'w').and_yield(fileio)
    File.should_not_receive(:exist?).with(filename)
    fileio.should_receive(:write).with('testdata')
    log.save_to_dir(dir, false)
  end
  
end
