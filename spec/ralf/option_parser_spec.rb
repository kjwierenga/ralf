require File.dirname(__FILE__) + '/../spec_helper'

require 'ralf'
require 'ralf/option_parser'

describe Ralf::OptionParser do

  before(:all) do
    @valid_arguments = {
      :range                 => [ '-r', '--range',                 ['today'] ],
      :aws_access_key_id     => [ '-a', '--aws-access-key-id',     'the_access_key_id' ],
      :aws_secret_access_key => [ '-s', '--aws-secret-access-key', 'the_secret_access_key' ],
      :output_dir_format     => [ '-f', '--output-dir-format',     ':year/:month/:day' ],
      :output_basedir        => [ '-d', '--output-basedir',        '/var/log/amazon_s3' ],
      :output_prefix         => [ '-p', '--output-prefix',         's3_combined' ],
      :config_file           => [ '-c', '--config-file',           '/my/etc/config.yaml' ],
      :log_file              => [ '-e', '--log-file',              '/var/log/ralf.log' ],
      # :rename_bucket_keys    => [ '-m', '--rename-bucket-keys',    nil ],
      :buckets               => [ '-b', '--buckets',               [ 'bucket1.mydomain.net', 'bucket2.mydomain.net' ] ],
      :list                  => [ '-l', '--list',                  nil ],
      :now                   => [ '-t', '--now',                   'yesterday' ],
      # :rename_bucket_keys    => [ '-m', '--rename-bucket-keys',    nil ],
    }
  end
  
  def to_argv(arguments, short = true)
    arguments.map { |k,v|
      arg = v[2].is_a?(Array) ? v[2].join(',') : v[2]
      [ (short ? v[0] : v[1]), arg ].compact
    }.flatten
  end
  
  it "should show help message" do
    output = StringIO.new
    options = Ralf::OptionParser.parse('-h'.split, output)
    options.should be_nil
    output.string.should_not be_empty
    output.string.should include("Show this message")
  end
  
  it "should parse all options short or long" do
    output = StringIO.new
    
    short_options = to_argv(@valid_arguments, true)
    long_options  = to_argv(@valid_arguments, false)

    [short_options, long_options].each do |the_options|
      options = Ralf::OptionParser.parse(the_options, output)
      
      @valid_arguments.each do |sym, opts|
        options.should have_key(sym)
        options[sym].should eql(opts[2] || true)
      end
    end
  
    output.string.should be_empty
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
  
end
