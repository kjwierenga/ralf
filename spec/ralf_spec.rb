require File.dirname(__FILE__) + '/spec_helper'

require 'ralf'

describe Ralf do

  before(:all) do
    # make sure we don't accidentally use actual credentials during test
    ENV['AWS_ACCESS_KEY_ID'], ENV['AWS_SECRET_ACCESS_KEY'] = nil, nil
    
    @key1 = {
      :name => 'log/access_log-2010-02-10-00-05-32-ZDRFGTCKUYVJCT',
      :data => 'This is content for key 1'
    }
    @key2 = {
      :name => 'log/access_log-2010-02-10-00-07-28-EFREUTERGRSGDH',
      :data => 'This is content for key 2'
    }
    @key3 = {
      :name => 'log/access_log-2010-02-11-00-09-32-SDHTFTFHDDDDDH',
      :data => 'This is content for key 3'
    }
    
    @aws_credentials = {
      :aws_access_key_id     => 'the_aws_access_key_id',
      :aws_secret_access_key => 'the_secret_access_key',
    }
    
    @valid_options = {
      :config_file => '',
      :output_file => './ralf/:year/:month/:day/:bucket.log',
    }.merge(@aws_credentials)
    
    @cli_config_path = 'my_ralf.conf'
    @cli_config = {
      :range       => '2010-02-10',
      :output_file => './ralf/:year/:month/:day/:bucket.log',
      :cache_dir   => '/tmp/ralf_cache/:bucket',
    }.merge(@aws_credentials)

    @tilde_config_path = File.expand_path('~/.ralf.conf')
    @tilde_config = {
      :range       => '2010-02-11',
      :output_file => '~/ralf/:year/:month/:day/:bucket.log',
      :cache_dir   => '~/ralf/cache/:bucket',
    }.merge(@aws_credentials)

    @etc_config_path = '/etc/ralf.conf'
    @etc_config = {
      :range       => '2010-02-12',
      :output_file => '/var/log/amazon/:year/:month/:day/:bucket.log',
      :cache_dir   => '/var/log/amazon/ralf_cache/:year/:month/:bucket',
    }.merge(@aws_credentials)
    
    # File = mock('File')
    @s3_mock = mock('s3_mock')
    Ralf::Bucket.s3 = @s3_mock

    @example_buckets = load_example_bucket_mocks
  end

  before(:each) do
    RightAws::S3.should_receive(:new).any_number_of_times.and_return(@s3_mock)
  end

  describe "Configuration Options" do

    it "should initialize properly" do
      ralf = Ralf.new({:output_file => 'here'}.merge(@aws_credentials))
      ralf.class.should eql(Ralf)
    end
    
    it "should read config file specified on command-line" do
      YAML.should_receive(:load_file).with(@cli_config_path).and_return(@cli_config)
      YAML.should_not_receive(:load_file).with(@tilde_config_path)
      YAML.should_not_receive(:load_file).with(@etc_config_path)
      ralf = Ralf.new(:config_file => @cli_config_path)
      ralf.config.should == Ralf::Config.new(@cli_config)
    end
    
    it "should read config file from '~/.ralf.conf' if it exists." do
      File.should_receive(:exist?).with(@tilde_config_path).and_return(true)
      YAML.should_receive(:load_file).with(@tilde_config_path).and_return(@tilde_config)
      ralf = Ralf.new
      ralf.config.should == Ralf::Config.new(@tilde_config)
    end
    
    it "should read config file from '/etc/ralf.conf' if ~/.ralf.conf does not exist." do
      File.should_receive(:exist?).with(@tilde_config_path).and_return(false)
      File.should_receive(:exist?).with(@etc_config_path).and_return(true)
      YAML.should_receive(:load_file).with(@etc_config_path).and_return(@etc_config)
      ralf = Ralf.new
      ralf.config.should == Ralf::Config.new(@etc_config)
    end
    
    it "should have only required option when :config_file is empty string" do
      File.should_not_receive(:exist?)
      ralf = Ralf.new({ :config_file => ''}.merge(@aws_credentials))
      ralf.config.should == Ralf::Config.new(@aws_credentials)
    end
    
    it "command-line options should override config file options" do
      File.should_receive(:exist?).with(@tilde_config_path).and_return(true)
      YAML.should_receive(:load_file).with(@tilde_config_path).and_return(@tilde_config)
      ralf = Ralf.new(@cli_config)
      ralf.config.should == Ralf::Config.new(@cli_config)
    end
  
    it "should raise an error when an nonexistent config file is given" do
      missing_file = 'the_missing_file.conf'
      File.should_receive(:open).with(missing_file).and_raise(Errno::ENOENT)
      lambda {
        ralf = Ralf.new(:config_file => missing_file)
      }.should raise_error(Errno::ENOENT)
    end

    it "should set the preferences" do
      ralf = Ralf.new(@cli_config)
      ralf.config.should == Ralf::Config.new(@cli_config)
    end
    
    it "should raise Ralf::Config::ConfigurationError when --output-file not specified" do
      lambda {
        Ralf.new(:output_file => nil)
      }.should raise_error(Ralf::Config::ConfigurationError)
    end

    it "should use AWS credentials provided in ENV" do
      lambda {
        Ralf.new
      }.should raise_error(Ralf::Config::ConfigurationError, 'aws_access_key_id missing, aws_secret_access_key missing')

      ENV['AWS_ACCESS_KEY_ID'], ENV['AWS_SECRET_ACCESS_KEY'] = 'aws_access_key', 'secret'
      lambda {
        Ralf.new
      }.should_not raise_error(Ralf::Config::ConfigurationError)
      
      # reset
      ENV['AWS_ACCESS_KEY_ID'], ENV['AWS_SECRET_ACCESS_KEY'] = nil, nil
    end

  end

  describe "Range handling" do
    
    it "should set range to today if unspecified" do
      now = Time.now
      Time.should_receive(:now).any_number_of_times.and_return(now)
      ralf = Ralf.new(@valid_options)
      date = now.strftime("%Y-%m-%d")

      ralf.config.range.to_s.should eql("#{date}..#{date}")
    end

    it "should set the range when single date given" do
      ralf = Ralf.new(@valid_options.merge(:range => '2010-02-01'))
      ralf.config.range.to_s.should eql('2010-02-01..2010-02-01')
    end

    it "should raise error when invalid date given" do
      lambda {
        ralf = Ralf.new(@valid_options.merge(:range => 'someday'))
        ralf.range.should be_nil
      }.should raise_error(Ralf::Config::RangeError, "invalid expression 'someday'")
    end

    it "should accept a range of 2 dates" do
      ralf = Ralf.new(@valid_options.merge(:range => ['2010-02-10', '2010-02-12']))
      ralf.config.range.to_s.should eql('2010-02-10..2010-02-12')
    end
    
    it "should raise error for range array with more than 2 items" do
      lambda {
        ralf = Ralf.new(@valid_options.merge(:range => ['2010-02-10', '2010-02-12', '2010-02-13']))
      }.should raise_error(ArgumentError, 'too many range items')
    end

    it "should treat a range with 1 date as a single date" do
      ralf = Ralf.new(@valid_options.merge(:range => '2010-02-10'))
      ralf.config.range.to_s.should eql('2010-02-10..2010-02-10')
    end

    it "should accept a range array with 1 date" do
      ralf = Ralf.new(@valid_options.merge(:range => ['2010-02-10']))
      ralf.config.range.to_s.should eql('2010-02-10..2010-02-10')
    end

    it "should accept a range defined by words" do
      Time.should_receive(:now).any_number_of_times.and_return(Time.parse('Mon Feb 17 09:41:00 +0100 2010'))
      ralf = Ralf.new(@valid_options.merge(:range => '2 days ago'))
      ralf.config.range.to_s.should eql('2010-02-15..2010-02-15')
    end

    it "should accept a month and convert it to a range" do
      Time.should_receive(:now).any_number_of_times.and_return(Time.parse('Mon Feb 17 09:41:00 +0100 2010'))
      ralf = Ralf.new(@valid_options.merge(:range => 'january'))
      ralf.config.range.to_s.should  eql('2010-01-01..2010-01-31')
    end
    
    it "should allow 'this month' with base 'yesterday'" do
      Time.should_receive(:now).any_number_of_times.and_return(Time.parse('Sat May 01 16:31:00 +0100 2010'))
      ralf = Ralf.new(@valid_options.merge(:range => 'this month', :now => 'yesterday'))
      ralf.config.range.to_s.should eql('2010-04-01..2010-04-30')
    end
    
    it "should support setting range first then change now (1st day of month)" do
      Time.should_receive(:now).any_number_of_times.and_return(Time.parse('Sat May 01 16:31:00 +0100 2010'))
      ralf = Ralf.new(@valid_options.merge(:range => 'this month'))
      ralf.config.range.to_s.should eql('2010-05-01..2010-05-01')
      ralf.config.merge!(:now => 'yesterday')
      ralf.config.range.to_s.should eql('2010-04-01..2010-04-30')
    end

    it "should support setting range first then change now" do
      Time.should_receive(:now).any_number_of_times.and_return(Time.parse('Sat May 08 16:31:00 +0100 2010'))
      ralf = Ralf.new(@valid_options.merge(:range => 'this month'))
      ralf.config.range.to_s.should eql('2010-05-01..2010-05-07')
      ralf.config.merge!(:now => '2010-05-06')
      ralf.config.range.to_s.should eql('2010-05-01..2010-05-06')
    end

  end

  describe "Handle Buckets" do

    it "should download, merge and convert logfiles" do
      @s3_mock.should_receive(:bucket).any_number_of_times do |name|
        @example_buckets[name]
      end
      
      File.stub(:makedirs)
      ralf = Ralf.new(@valid_options.merge(:cache_dir   => '/var/log/s3/cache/:bucket',
                                           :output_file => '/var/log/s3/:bucket.log',
                                           :buckets     => 'test1',
                                           :range       => ['2010-02-01', '2010-02-12']))
      
      alfio = StringIO.new
      File.should_receive(:open).with('/var/log/s3/test1.log.alf', 'w').and_yield(alfio)
      
      Ralf.should_receive(:download_logs).any_number_of_times do |bucket, date, dir|
        expected_bucket = Ralf::Bucket.new(@example_buckets['test1'])
        [ :name, :logging_enabled?, :targetbucket, :targetprefix ].each do |attr|
          bucket.send(attr).should eql(expected_bucket.send(attr))
        end
        ralf.config.range.should include(date)
        dir.should eql("/var/log/s3/cache/test1")
        
        log_files = []
        case date
        when Date.new(2010,02,10)
          log_files << '/var/log/s3/cache/test1/2010-02-10-00-05-32-ZDRFGTCKUYVJCT'
        when Date.new(2010,02,11)
          log_files << '/var/log/s3/cache/test1/2010-02-11-00-05-32-ZDRFGTCKUYVJCT'
        end
        log_files
      end

      Ralf.should_receive(:convert_to_common_log_format).with(
        "/var/log/s3/test1.log.alf", "/var/log/s3/test1.log")
      
      LogMerge::Merger.should_receive(:merge).with(alfio,
        *@example_buckets['test1'].keys.map{|k| "/var/log/s3/cache/test1/#{k.name.gsub('logs/', '')}"})
      
      ralf.run()
    end
    
    it "should raise error when output_file option is missing" do
      ralf = Ralf.new(@aws_credentials)
      lambda {
        ralf.run
      }.should raise_error(ArgumentError, "--output-file required")
    end
    
    it "should raise error when output_file option requires :bucket variable" do
      ralf = Ralf.new(@aws_credentials.merge(:output_file => '/tmp/ralf/ralf.log'))
      lambda {
        ralf.run
      }.should raise_error(ArgumentError, "--output-file requires ':bucket' variable")
    end

  end

  describe "Conversion of Amazon Log Format to Common Log Format" do
  
    it "should convert output files to common_log_format" do
      input_log = StringIO.new
      input_log.string = <<EOF_INPUT
2cf7e6b06335c0689c6d29163df5bb001c96870cd78609e3845f1ed76a632621 assets.staging.kerkdienstgemist.nl [10/Feb/2010:07:17:01 +0000] 10.32.219.38 3272ee65a908a7677109fedda345db8d9554ba26398b2ca10581de88777e2b61 784FD457838EFF42 REST.GET.ACL - "GET /?acl HTTP/1.1" 200 - 1384 - 399 - "-" "Jakarta Commons-HttpClient/3.0" -
2cf7e6b06335c0689c6d29163df5bb001c96870cd78609e3845f1ed76a632621 assets.staging.kerkdienstgemist.nl [10/Feb/2010:07:17:02 +0000] 10.32.219.38 3272ee65a908a7677109fedda345db8d9554ba26398b2ca10581de88777e2b61 6E239BC5A4AC757C SOAP.PUT.OBJECT logs/2010-02-10-07-17-02-F6EFD00DAB9A08B6 "POST /soap/ HTTP/1.1" 200 - 797 686 63 31 "-" "Axis/1.3" -
2cf7e6b06335c0689c6d29163df5bb001c96870cd78609e3845f1ed76a632621 assets.staging.kerkdienstgemist.nl [10/Feb/2010:07:24:40 +0000] 10.217.37.15 - 0B76C90B3634290B REST.GET.ACL - "GET /?acl HTTP/1.1" 307 TemporaryRedirect 488 - 7 - "-" "Jakarta Commons-HttpClient/3.0" -
EOF_INPUT

      clf_log =<<EOF_OUTPUT
10.32.219.38 - 3272ee65a908a7677109fedda345db8d9554ba26398b2ca10581de88777e2b61 [10/Feb/2010:07:17:01 +0000] "GET /?acl HTTP/1.1" 200 1384 "-" "Jakarta Commons-HttpClient/3.0"
10.32.219.38 - 3272ee65a908a7677109fedda345db8d9554ba26398b2ca10581de88777e2b61 [10/Feb/2010:07:17:02 +0000] "POST /soap/ HTTP/1.1" 200 797 "-" "Axis/1.3"
10.217.37.15 - - [10/Feb/2010:07:24:40 +0000] "GET /?acl HTTP/1.1" 307 488 "-" "Jakarta Commons-HttpClient/3.0"
EOF_OUTPUT

      output_log = StringIO.new
      
      File.should_receive(:open).with('input_file', 'r').and_yield(input_log)
      File.should_receive(:open).with('output_file', 'w').and_return(output_log)

      Ralf.convert_to_common_log_format('input_file', 'output_file')
      output_log.string.should eql(clf_log)
    end

    it "should mark invalid lines with '# ERROR: '" do
      $stderr = StringIO.new
      invalid_line = "this is an invalid log line"
      Ralf.translate_to_clf(invalid_line)
      $stderr.string.should eql("# ERROR: #{invalid_line}\n")
    end

  end
  
end
