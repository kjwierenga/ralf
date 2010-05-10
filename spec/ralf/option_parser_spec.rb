require File.dirname(__FILE__) + '/../spec_helper'

require 'ralf'
require 'ralf/option_parser'

describe Ralf::OptionParser do

  before(:all) do
    @valid_arguments = [
      [ :buckets, '--buckets', [ 'bucket1.mydomain.net', 'bucket2.mydomain.net' ] ],
      [ :buckets, '-b',        [ 'bucket1.mydomain.net', 'bucket2.mydomain.net' ] ],
      
      [ :range, '--range', ['today'] ],
      [ :range, '-r',      ['today'] ],

      [ :now, '--now', 'yesterday' ],
      [ :now, '-t',    'yesterday' ],
      
      [ :output_file, '--output-file', '/var/log/s3/:year/:month/:bucket.log' ],
      [ :output_file, '-o',            '/var/log/s3/:year/:month/:bucket.log' ],

      [ :cache_dir, '--cache-dir', '/var/run/s3_cache/:bucket/:year/:month/:day' ],
      [ :cache_dir, '-x',          '/var/run/s3_cache/:bucket/:year/:month/:day' ],
      
      [ :list, '--list', true ],
      [ :list, '-l',     true ],
      
      [ :debug, '--debug', true ],
      [ :debug, '-d',      true ],
      [ :debug, '--debug', 'aws' ],
      [ :debug, '-d',      'aws' ],
      
      [ :config_file, '--config-file', '/my/config/file.conf' ],
      [ :config_file, '-c',            '/my/config/file.conf' ],
      [ :config_file, '--config-file', '' ],
      [ :config_file, '-c',            '' ],
      
      # :rename_bucket_keys    => [ '-m', '--rename-bucket-keys',    nil ],
    ]
  end
  
  it "should show help message" do
    output = StringIO.new
    options = Ralf::OptionParser.parse('-h'.split, output)
    options.should be_nil
    output.string.should_not be_empty
    output.string.should include("Show this message")
  end
  
  it "should show version" do
    output = StringIO.new
    File.should_receive(:read).and_return('1.2.3')
    options = Ralf::OptionParser.parse('-v'.split, output)
    options.should be_nil
    output.string.should_not be_empty
    output.string.should include("1.2.3")
  end

  it "should parse all options short or long" do
    output = StringIO.new
    
    @valid_arguments.to_a.each do |argument_spec|
      options = to_argv_array(argument_spec)
      config = Ralf::OptionParser.parse(options, output)
    
      config.should have_key(argument_spec.first)
      config[argument_spec.first].should eql(argument_spec.last)

      output.string.should be_empty
    end
  
  end

  it "should allow two dates for range" do
    output = StringIO.new
    
    options = Ralf::OptionParser.parse("--range yesterday,today".split, output)
    
    options.should have_key(:range)
    options[:range].should eql(['yesterday', 'today'])
  end
  
  it "should produce error for missing argument" do
    output = StringIO.new
    
    lambda {
      options = Ralf::OptionParser.parse("--range".split, output)
    }.should raise_error(OptionParser::MissingArgument)
  end
  
  private
  
  def to_argv_array(spec)
    spec[1..-1].delete_if{ |v| true == v }.map{ |v| v.is_a?(Array) ? v.join(',') : v }
  end
  
end
