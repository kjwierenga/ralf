require File.dirname(__FILE__) + '/../spec_helper'

require 'ralf'
require 'ralf/option_parser'

describe Ralf::OptionParser do
  
  it "should show help message" do
    output = StringIO.new
    options = Ralf::OptionParser.parse('-h'.split, output)
    options.should be_nil
    output.string.should_not be_empty
    output.string.should include("Show this message")
  end
  
  it "should parse all short options" do
    output = StringIO.new
    
    arguments =
      "-r today -a the_access_key_id -s the_secret_access_key " +
      "-f :year/:month/:day -d /var/log/amazon_s3 -p s3_combined " +
      "-c /my/etc/config.yaml -l /var/log/ralf.log -m"

    options = Ralf::OptionParser.parse(arguments.split, output)
    
    [ :range, :aws_access_key_id, :aws_secret_access_key,
      :output_dir_format, :output_basedir, :output_prefix, :log_file,
      :rename_bucket_keys ].each do |key|
      options.should have_key(key)
    end
    options[:range].should eql(['today'])
    options[:aws_access_key_id].should eql('the_access_key_id')
    options[:aws_secret_access_key].should eql('the_secret_access_key')
    options[:output_dir_format].should eql(':year/:month/:day')
    options[:output_basedir].should eql('/var/log/amazon_s3')
    options[:output_prefix].should eql('s3_combined')
    options[:config_file].should eql('/my/etc/config.yaml')
    options[:log_file].should eql('/var/log/ralf.log')
    options[:rename_bucket_keys].should be_true
    
    output.string.should be_empty
  end
  
  it "should parse all long options" do
    output = StringIO.new
    
    arguments = 
      "--range today --aws-access-key-id the_access_key_id " +
      "--aws-secret-access-key the_secret_access_key " +
      "--output-dir-format :year/:month/:day --output-basedir /var/log/amazon_s3 " +
      "--output-prefix s3_combined --config-file /my/etc/config.yaml " +
      "--log-file /var/log/ralf.log --rename-bucket-keys"

    options = Ralf::OptionParser.parse(arguments.split, output)
    
    [ :range, :aws_access_key_id, :aws_secret_access_key,
      :output_dir_format, :output_basedir, :output_prefix, :config_file, :log_file,
      :rename_bucket_keys ].each do |key|
      options.should have_key(key)
    end
    options[:range].should eql(['today'])
    options[:aws_access_key_id].should eql('the_access_key_id')
    options[:aws_secret_access_key].should eql('the_secret_access_key')
    options[:output_dir_format].should eql(':year/:month/:day')
    options[:output_basedir].should eql('/var/log/amazon_s3')
    options[:output_prefix].should eql('s3_combined')
    options[:config_file].should eql('/my/etc/config.yaml')
    options[:log_file].should eql('/var/log/ralf.log')
    options[:rename_bucket_keys].should be_true
    
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
