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
      YAML.should_not_receive(:load_file)
      ralf = Ralf.new({:output_file => 'here', :config_file => ''}.merge(@aws_credentials))
      ralf.class.should eql(Ralf)
    end
    
    it "should read config file specified on command-line" do
      YAML.should_receive(:load_file).with(@cli_config_path).and_return(@cli_config)
      YAML.should_not_receive(:load_file).with(@tilde_config_path)
      YAML.should_not_receive(:load_file).with(@etc_config_path)
      ralf = Ralf.new(:config_file => @cli_config_path)
      ralf.config.should == Ralf::Config.new(@cli_config)
    end
    
    it "should read config file from '~/.ralf.conf' if not running as root." do
      Process.should_receive(:uid).and_return(1)
      File.should_receive(:exist?).with(@tilde_config_path).and_return(true)
      YAML.should_receive(:load_file).with(@tilde_config_path).and_return(@tilde_config)
      ralf = Ralf.new
      ralf.config.should == Ralf::Config.new(@tilde_config)
    end
    
    it "should read config file from '/etc/ralf.conf' if running as root." do
      Process.should_receive(:uid).and_return(0)
      File.should_receive(:exist?).with(@etc_config_path).and_return(true)
      YAML.should_receive(:load_file).with(@etc_config_path).and_return(@etc_config)
      ralf = Ralf.new
      ralf.config.should == Ralf::Config.new(@etc_config)
    end

    it "should read config file from '~/.ralf.conf' if running as root and /etc/ralf doesn't exist." do
      Process.should_receive(:uid).and_return(0)
      File.should_receive(:exist?).with(@etc_config_path).and_return(true)
      YAML.should_receive(:load_file).with(@etc_config_path).and_return(@etc_config)
      ralf = Ralf.new
      ralf.config.should == Ralf::Config.new(@etc_config)
    end
    
    it "should have only required option when :config_file is empty string" do
      YAML.should_not_receive(:load_file)
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
      YAML.should_not_receive(:load_file)
      ralf = Ralf.new(@cli_config.merge(:config_file => ''))
      ralf.config.should == Ralf::Config.new(@cli_config)
    end
    
    it "should raise Ralf::Config::ConfigurationError when --output-file not specified" do
      YAML.should_not_receive(:load_file)
      lambda {
        Ralf.new(:output_file => nil, :config_file => '')
      }.should raise_error(Ralf::Config::ConfigurationError)
    end

    it "should use AWS credentials provided in ENV" do
      YAML.should_not_receive(:load_file)
      lambda {
        Ralf.new(:config_file => '')
      }.should raise_error(Ralf::Config::ConfigurationError, 'aws_access_key_id missing, aws_secret_access_key missing')

      ENV['AWS_ACCESS_KEY_ID'], ENV['AWS_SECRET_ACCESS_KEY'] = 'aws_access_key', 'secret'
      lambda {
        Ralf.new(:config_file => '')
      }.should_not raise_error(Ralf::Config::ConfigurationError)
      
      # reset
      ENV['AWS_ACCESS_KEY_ID'], ENV['AWS_SECRET_ACCESS_KEY'] = nil, nil
    end

  end

  describe "Range handling" do
    
    it "should set range to today if unspecified" do
      YAML.should_not_receive(:load_file)
      now = Time.now
      Time.should_receive(:now).any_number_of_times.and_return(now)
      ralf = Ralf.new(@valid_options)
      date = now.strftime("%Y-%m-%d")

      ralf.config.range.to_s.should eql("#{date}..#{date}")
    end

    it "should set the range when single date given" do
      YAML.should_not_receive(:load_file)
      ralf = Ralf.new(@valid_options.merge(:range => '2010-02-01'))
      ralf.config.range.to_s.should eql('2010-02-01..2010-02-01')
    end

    it "should raise error when invalid date given" do
      YAML.should_not_receive(:load_file)
      lambda {
        ralf = Ralf.new(@valid_options.merge(:range => 'someday'))
        ralf.range.should be_nil
      }.should raise_error(Ralf::Config::RangeError, "invalid expression 'someday'")
    end

    it "should accept a range of 2 dates" do
      YAML.should_not_receive(:load_file)
      ralf = Ralf.new(@valid_options.merge(:range => ['2010-02-10', '2010-02-12']))
      ralf.config.range.to_s.should eql('2010-02-10..2010-02-12')
    end
    
    it "should raise error for range array with more than 2 items" do
      YAML.should_not_receive(:load_file)
      lambda {
        ralf = Ralf.new(@valid_options.merge(:range => ['2010-02-10', '2010-02-12', '2010-02-13']))
      }.should raise_error(ArgumentError, 'too many range items')
    end

    it "should treat a range with 1 date as a single date" do
      YAML.should_not_receive(:load_file)
      ralf = Ralf.new(@valid_options.merge(:range => '2010-02-10'))
      ralf.config.range.to_s.should eql('2010-02-10..2010-02-10')
    end

    it "should accept a range array with 1 date" do
      YAML.should_not_receive(:load_file)
      ralf = Ralf.new(@valid_options.merge(:range => ['2010-02-10']))
      ralf.config.range.to_s.should eql('2010-02-10..2010-02-10')
    end

    it "should accept a range defined by words" do
      YAML.should_not_receive(:load_file)
      Time.should_receive(:now).any_number_of_times.and_return(Time.parse('Mon Feb 17 09:41:00 +0100 2010'))
      ralf = Ralf.new(@valid_options.merge(:range => '2 days ago'))
      ralf.config.range.to_s.should eql('2010-02-15..2010-02-15')
    end

    it "should accept a month and convert it to a range" do
      YAML.should_not_receive(:load_file)
      Time.should_receive(:now).any_number_of_times.and_return(Time.parse('Mon Feb 17 09:41:00 +0100 2010'))
      ralf = Ralf.new(@valid_options.merge(:range => 'january'))
      ralf.config.range.to_s.should  eql('2010-01-01..2010-01-31')
    end
    
    it "should allow 'this month' with base 'yesterday'" do
      YAML.should_not_receive(:load_file)
      Time.should_receive(:now).any_number_of_times.and_return(Time.parse('Sat May 01 16:31:00 +0100 2010'))
      ralf = Ralf.new(@valid_options.merge(:range => 'this month', :now => 'yesterday'))
      ralf.config.range.to_s.should eql('2010-04-01..2010-04-30')
    end
    
    it "should support setting range first then change now (1st day of month)" do
      YAML.should_not_receive(:load_file)
      Time.should_receive(:now).any_number_of_times.and_return(Time.parse('Sat May 01 16:31:00 +0100 2010'))
      ralf = Ralf.new(@valid_options.merge(:range => 'this month'))
      ralf.config.range.to_s.should eql('2010-05-01..2010-05-01')
      ralf.config.merge!(:now => 'yesterday')
      ralf.config.range.to_s.should eql('2010-04-01..2010-04-30')
    end

    it "should support setting range first then change now" do
      YAML.should_not_receive(:load_file)
      Time.should_receive(:now).any_number_of_times.and_return(Time.parse('Sat May 08 16:31:00 +0100 2010'))
      ralf = Ralf.new(@valid_options.merge(:range => 'this month'))
      ralf.config.range.to_s.should eql('2010-05-01..2010-05-07')
      ralf.config.merge!(:now => '2010-05-06')
      ralf.config.range.to_s.should eql('2010-05-01..2010-05-06')
    end

  end

  describe "Handle Buckets" do

    it "should download, merge and convert logfiles" do
      YAML.should_not_receive(:load_file)
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
      YAML.should_not_receive(:load_file)
      ralf = Ralf.new(@aws_credentials.merge(:config_file => ''))
      lambda {
        ralf.run
      }.should raise_error(ArgumentError, "--output-file required")
    end
    
    it "should raise error when output_file option requires :bucket variable" do
      YAML.should_not_receive(:load_file)
      ralf = Ralf.new(@aws_credentials.merge(:output_file => '/tmp/ralf/ralf.log', :config_file => ''))
      lambda {
        ralf.run
      }.should raise_error(ArgumentError, "--output-file requires ':bucket' variable")
    end

  end

  describe "Conversion of Amazon Log Format to Common Log Format" do
  
    it "should convert output files to common_log_format" do
      input_log = StringIO.new
      
      # last two lines are ignored because they don't match
      input_log.string = <<EOF_INPUT
2cf7e6b06335c0689c6d29163df5bb001c96870cd78609e3845f1ed76a632621 assets.staging.kerkdienstgemist.nl [10/Feb/2010:07:17:01 +0000] 10.32.219.38 3272ee65a908a7677109fedda345db8d9554ba26398b2ca10581de88777e2b61 784FD457838EFF42 REST.GET.ACL - "GET /?acl HTTP/1.1" 200 - 1384 - 399 - "-" "Jakarta Commons-HttpClient/3.0" -
2cf7e6b06335c0689c6d29163df5bb001c96870cd78609e3845f1ed76a632621 assets.staging.kerkdienstgemist.nl [10/Feb/2010:07:17:02 +0000] 10.32.219.38 3272ee65a908a7677109fedda345db8d9554ba26398b2ca10581de88777e2b61 6E239BC5A4AC757C SOAP.PUT.OBJECT logs/2010-02-10-07-17-02-F6EFD00DAB9A08B6 "POST /soap/ HTTP/1.1" 200 - 797 686 63 31 "-" "Axis/1.3" -
2cf7e6b06335c0689c6d29163df5bb001c96870cd78609e3845f1ed76a632621 assets.staging.kerkdienstgemist.nl [10/Feb/2010:07:24:40 +0000] 10.217.37.15 - 0B76C90B3634290B REST.GET.ACL - "GET /?acl HTTP/1.1" 307 TemporaryRedirect 488 - 7 - "-" "Jakarta Commons-HttpClient/3.0" -
2cf7e6b06335c0689c6d29163df5bb001c96870cd78609e3845f1ed76a632621 media.staging.kerkdienstgemist.nl [17/Sep/2010:13:38:36 +0000] 85.113.244.146 2cf7e6b06335c0689c6d29163df5bb001c96870cd78609e3845f1ed76a632621 71F7D2AAA93B0A05 REST.COPY.OBJECT_GET 10010150/2010-08-29-0930.mp3 - 200 - - 13538337 - - - - -
2cf7e6b06335c0689c6d29163df5bb001c96870cd78609e3845f1ed76a632621 media.staging.kerkdienstgemist.nl [17/Sep/2010:13:38:37 +0000] 85.113.244.146 2cf7e6b06335c0689c6d29163df5bb001c96870cd78609e3845f1ed76a632621 7CC5E3D09AE78CAE REST.COPY.OBJECT_GET 10010150/2010-09-05-1000.mp3 - 200 - - 9860402 - - - - -
EOF_INPUT

      clf_log =<<EOF_OUTPUT
10.32.219.38 - 3272ee65a908a7677109fedda345db8d9554ba26398b2ca10581de88777e2b61 [10/Feb/2010:07:17:01 +0000] "GET /?acl HTTP/1.1" 200 1384 "-" "Jakarta Commons-HttpClient/3.0" 0
10.32.219.38 - 3272ee65a908a7677109fedda345db8d9554ba26398b2ca10581de88777e2b61 [10/Feb/2010:07:17:02 +0000] "POST /soap/ HTTP/1.1" 200 797 "-" "Axis/1.3" 0
10.217.37.15 - - [10/Feb/2010:07:24:40 +0000] "GET /?acl HTTP/1.1" 307 488 "-" "Jakarta Commons-HttpClient/3.0" 0
85.113.244.146 - 2cf7e6b06335c0689c6d29163df5bb001c96870cd78609e3845f1ed76a632621 [17/Sep/2010:13:38:36 +0000] "POST /10010150/2010-08-29-0930.mp3 HTTP/1.1" 200 - "-" "REST.COPY.OBJECT_GET" 0
85.113.244.146 - 2cf7e6b06335c0689c6d29163df5bb001c96870cd78609e3845f1ed76a632621 [17/Sep/2010:13:38:37 +0000] "POST /10010150/2010-09-05-1000.mp3 HTTP/1.1" 200 - "-" "REST.COPY.OBJECT_GET" 0
EOF_OUTPUT

      output_log = StringIO.new
      
      File.should_receive(:open).with('output_file', 'w').and_return(output_log)
      File.should_receive(:open).with('input_file', 'r').and_yield(input_log)
      
      # $stderr.should_receive(:puts).with("# ERROR: 2cf7e6b06335c0689c6d29163df5bb001c96870cd78609e3845f1ed76a632621 media.staging.kerkdienstgemist.nl [17/Sep/2010:13:38:36 +0000] 85.113.244.146 2cf7e6b06335c0689c6d29163df5bb001c96870cd78609e3845f1ed76a632621 71F7D2AAA93B0A05 REST.COPY.OBJECT_GET 10010150/2010-08-29-0930.mp3 - 200 - - 13538337 - - - - -\n")
      # $stderr.should_receive(:puts).with("# ERROR: 2cf7e6b06335c0689c6d29163df5bb001c96870cd78609e3845f1ed76a632621 media.staging.kerkdienstgemist.nl [17/Sep/2010:13:38:37 +0000] 85.113.244.146 2cf7e6b06335c0689c6d29163df5bb001c96870cd78609e3845f1ed76a632621 7CC5E3D09AE78CAE REST.COPY.OBJECT_GET 10010150/2010-09-05-1000.mp3 - 200 - - 9860402 - - - - -\n")

      Ralf.convert_to_common_log_format('input_file', 'output_file')
      output_log.string.should eql(clf_log)
    end
    
    it "should estimate Actual Bytes Sent of transfers from Bytes Sent and Total Time" do
      output_log = StringIO.new
      winamp_log = File.open(File.join(File.dirname(__FILE__), 'fixtures', 'winamp.txt'), 'r')

      File.should_receive(:open).with('output_file', 'w').and_return(output_log)
      File.should_receive(:open).with('input_file',  'r').and_yield(winamp_log)

      Ralf.convert_to_common_log_format('input_file', 'output_file')

#       expected_clf_log =<<EOF_OUTPUT
# 84.82.12.240 - 2cf7e6b06335c0689c6d29163df5bb001c96870cd78609e3845f1ed76a632621 [03/Nov/2010:15:57:29 +0000] "GET /10122150/2010-10-31-0930.mp3?Signature=5n2%2B8hrDvgSbP6OJRP1vVav42uU%3D&Expires=1288807041&AWSAccessKeyId=AKIAI3XHXJPFSJW2UQAQ HTTP/1.0" 200 4215272 "-" "WinampMPEG/5.56, Ultravox/2.1" 5
# 84.82.12.240 - 2cf7e6b06335c0689c6d29163df5bb001c96870cd78609e3845f1ed76a632621 [03/Nov/2010:15:57:34 +0000] "GET /10122150/2010-10-31-0930.mp3?Signature=5n2%2B8hrDvgSbP6OJRP1vVav42uU%3D&Expires=1288807041&AWSAccessKeyId=AKIAI3XHXJPFSJW2UQAQ HTTP/1.1" 206 4210177 "-" "WinampMPEG/5.56" 4
# 84.82.12.240 - 2cf7e6b06335c0689c6d29163df5bb001c96870cd78609e3845f1ed76a632621 [03/Nov/2010:15:57:38 +0000] "GET /10122150/2010-10-31-0930.mp3?Signature=5n2%2B8hrDvgSbP6OJRP1vVav42uU%3D&Expires=1288807041&AWSAccessKeyId=AKIAI3XHXJPFSJW2UQAQ HTTP/1.1" 206 4200071 "-" "WinampMPEG/5.56" 4
# 84.82.12.240 - 2cf7e6b06335c0689c6d29163df5bb001c96870cd78609e3845f1ed76a632621 [03/Nov/2010:15:57:42 +0000] "GET /10122150/2010-10-31-0930.mp3?Signature=5n2%2B8hrDvgSbP6OJRP1vVav42uU%3D&Expires=1288807041&AWSAccessKeyId=AKIAI3XHXJPFSJW2UQAQ HTTP/1.1" 206 4233474 "-" "WinampMPEG/5.56" 3
# 84.82.12.240 - 2cf7e6b06335c0689c6d29163df5bb001c96870cd78609e3845f1ed76a632621 [03/Nov/2010:15:57:45 +0000] "GET /10122150/2010-10-31-0930.mp3?Signature=5n2%2B8hrDvgSbP6OJRP1vVav42uU%3D&Expires=1288807041&AWSAccessKeyId=AKIAI3XHXJPFSJW2UQAQ HTTP/1.1" 206 4230605 "-" "WinampMPEG/5.56" 13
# 84.82.12.240 - 2cf7e6b06335c0689c6d29163df5bb001c96870cd78609e3845f1ed76a632621 [03/Nov/2010:15:57:58 +0000] "GET /10122150/2010-10-31-0930.mp3?Signature=5n2%2B8hrDvgSbP6OJRP1vVav42uU%3D&Expires=1288807041&AWSAccessKeyId=AKIAI3XHXJPFSJW2UQAQ HTTP/1.1" 206 3920952 "-" "WinampMPEG/5.56" 3
# 84.82.12.240 - 2cf7e6b06335c0689c6d29163df5bb001c96870cd78609e3845f1ed76a632621 [03/Nov/2010:15:58:01 +0000] "GET /10122150/2010-10-31-0930.mp3?Signature=5n2%2B8hrDvgSbP6OJRP1vVav42uU%3D&Expires=1288807041&AWSAccessKeyId=AKIAI3XHXJPFSJW2UQAQ HTTP/1.1" 206 4226689 "-" "WinampMPEG/5.56" 3
# 84.82.12.240 - 2cf7e6b06335c0689c6d29163df5bb001c96870cd78609e3845f1ed76a632621 [03/Nov/2010:15:58:04 +0000] "GET /10122150/2010-10-31-0930.mp3?Signature=5n2%2B8hrDvgSbP6OJRP1vVav42uU%3D&Expires=1288807041&AWSAccessKeyId=AKIAI3XHXJPFSJW2UQAQ HTTP/1.1" 206 4217974 "-" "WinampMPEG/5.56" 3
# 84.82.12.240 - 2cf7e6b06335c0689c6d29163df5bb001c96870cd78609e3845f1ed76a632621 [03/Nov/2010:15:58:07 +0000] "GET /10122150/2010-10-31-0930.mp3?Signature=5n2%2B8hrDvgSbP6OJRP1vVav42uU%3D&Expires=1288807041&AWSAccessKeyId=AKIAI3XHXJPFSJW2UQAQ HTTP/1.1" 206 4227033 "-" "WinampMPEG/5.56" 3
# 84.82.12.240 - 2cf7e6b06335c0689c6d29163df5bb001c96870cd78609e3845f1ed76a632621 [03/Nov/2010:15:58:10 +0000] "GET /10122150/2010-10-31-0930.mp3?Signature=5n2%2B8hrDvgSbP6OJRP1vVav42uU%3D&Expires=1288807041&AWSAccessKeyId=AKIAI3XHXJPFSJW2UQAQ HTTP/1.1" 206 4229800 "-" "WinampMPEG/5.56" 6
# 84.82.12.240 - 2cf7e6b06335c0689c6d29163df5bb001c96870cd78609e3845f1ed76a632621 [03/Nov/2010:15:58:16 +0000] "GET /10122150/2010-10-31-0930.mp3?Signature=5n2%2B8hrDvgSbP6OJRP1vVav42uU%3D&Expires=1288807041&AWSAccessKeyId=AKIAI3XHXJPFSJW2UQAQ HTTP/1.1" 206 4169752 "-" "WinampMPEG/5.56" 3
# 84.82.12.240 - 2cf7e6b06335c0689c6d29163df5bb001c96870cd78609e3845f1ed76a632621 [03/Nov/2010:15:58:19 +0000] "GET /10122150/2010-10-31-0930.mp3?Signature=5n2%2B8hrDvgSbP6OJRP1vVav42uU%3D&Expires=1288807041&AWSAccessKeyId=AKIAI3XHXJPFSJW2UQAQ HTTP/1.1" 206 4221938 "-" "WinampMPEG/5.56" 3
# 84.82.12.240 - 2cf7e6b06335c0689c6d29163df5bb001c96870cd78609e3845f1ed76a632621 [03/Nov/2010:15:58:22 +0000] "GET /10122150/2010-10-31-0930.mp3?Signature=5n2%2B8hrDvgSbP6OJRP1vVav42uU%3D&Expires=1288807041&AWSAccessKeyId=AKIAI3XHXJPFSJW2UQAQ HTTP/1.1" 206 4116176 "-" "WinampMPEG/5.56" 4
# 84.82.12.240 - 2cf7e6b06335c0689c6d29163df5bb001c96870cd78609e3845f1ed76a632621 [03/Nov/2010:15:58:26 +0000] "GET /10122150/2010-10-31-0930.mp3?Signature=5n2%2B8hrDvgSbP6OJRP1vVav42uU%3D&Expires=1288807041&AWSAccessKeyId=AKIAI3XHXJPFSJW2UQAQ HTTP/1.1" 206 3134615 "-" "WinampMPEG/5.56" 0
# 84.82.12.240 - 2cf7e6b06335c0689c6d29163df5bb001c96870cd78609e3845f1ed76a632621 [03/Nov/2010:15:58:33 +0000] "GET /10122150/2010-10-31-0930.mp3?Signature=5n2%2B8hrDvgSbP6OJRP1vVav42uU%3D&Expires=1288807041&AWSAccessKeyId=AKIAI3XHXJPFSJW2UQAQ HTTP/1.1" 206 2546843 "-" "WinampMPEG/5.56" 0
# 84.82.12.240 - 2cf7e6b06335c0689c6d29163df5bb001c96870cd78609e3845f1ed76a632621 [03/Nov/2010:15:58:37 +0000] "GET /10122150/2010-10-31-0930.mp3?Signature=5n2%2B8hrDvgSbP6OJRP1vVav42uU%3D&Expires=1288807041&AWSAccessKeyId=AKIAI3XHXJPFSJW2UQAQ HTTP/1.1" 206 1861439 "-" "WinampMPEG/5.56" 0
# 84.82.12.240 - 2cf7e6b06335c0689c6d29163df5bb001c96870cd78609e3845f1ed76a632621 [03/Nov/2010:15:58:41 +0000] "GET /10122150/2010-10-31-0930.mp3?Signature=5n2%2B8hrDvgSbP6OJRP1vVav42uU%3D&Expires=1288807041&AWSAccessKeyId=AKIAI3XHXJPFSJW2UQAQ HTTP/1.1" 206 1273664 "-" "WinampMPEG/5.56" 0
# 84.82.12.240 - 2cf7e6b06335c0689c6d29163df5bb001c96870cd78609e3845f1ed76a632621 [03/Nov/2010:15:58:44 +0000] "GET /10122150/2010-10-31-0930.mp3?Signature=5n2%2B8hrDvgSbP6OJRP1vVav42uU%3D&Expires=1288807041&AWSAccessKeyId=AKIAI3XHXJPFSJW2UQAQ HTTP/1.1" 206 783806 "-" "WinampMPEG/5.56" 0
# 84.82.12.240 - 2cf7e6b06335c0689c6d29163df5bb001c96870cd78609e3845f1ed76a632621 [03/Nov/2010:15:58:48 +0000] "GET /10122150/2010-10-31-0930.mp3?Signature=5n2%2B8hrDvgSbP6OJRP1vVav42uU%3D&Expires=1288807041&AWSAccessKeyId=AKIAI3XHXJPFSJW2UQAQ HTTP/1.1" 206 3428645 "-" "WinampMPEG/5.56" 0
# 84.82.12.240 - 2cf7e6b06335c0689c6d29163df5bb001c96870cd78609e3845f1ed76a632621 [03/Nov/2010:15:58:51 +0000] "GET /10122150/2010-10-31-0930.mp3?Signature=5n2%2B8hrDvgSbP6OJRP1vVav42uU%3D&Expires=1288807041&AWSAccessKeyId=AKIAI3XHXJPFSJW2UQAQ HTTP/1.1" 206 4232818 "-" "WinampMPEG/5.56" 4
# 84.82.12.240 - 2cf7e6b06335c0689c6d29163df5bb001c96870cd78609e3845f1ed76a632621 [03/Nov/2010:15:58:55 +0000] "GET /10122150/2010-10-31-0930.mp3?Signature=5n2%2B8hrDvgSbP6OJRP1vVav42uU%3D&Expires=1288807041&AWSAccessKeyId=AKIAI3XHXJPFSJW2UQAQ HTTP/1.1" 206 4308854 "-" "WinampMPEG/5.56" 5
# 84.82.12.240 - 2cf7e6b06335c0689c6d29163df5bb001c96870cd78609e3845f1ed76a632621 [03/Nov/2010:15:59:00 +0000] "GET /10122150/2010-10-31-0930.mp3?Signature=5n2%2B8hrDvgSbP6OJRP1vVav42uU%3D&Expires=1288807041&AWSAccessKeyId=AKIAI3XHXJPFSJW2UQAQ HTTP/1.1" 206 4238246 "-" "WinampMPEG/5.56" 6
# 84.82.12.240 - 2cf7e6b06335c0689c6d29163df5bb001c96870cd78609e3845f1ed76a632621 [03/Nov/2010:15:59:06 +0000] "GET /10122150/2010-10-31-0930.mp3?Signature=5n2%2B8hrDvgSbP6OJRP1vVav42uU%3D&Expires=1288807041&AWSAccessKeyId=AKIAI3XHXJPFSJW2UQAQ HTTP/1.1" 206 4280986 "-" "WinampMPEG/5.56" 3
# 84.82.12.240 - 2cf7e6b06335c0689c6d29163df5bb001c96870cd78609e3845f1ed76a632621 [03/Nov/2010:15:59:09 +0000] "GET /10122150/2010-10-31-0930.mp3?Signature=5n2%2B8hrDvgSbP6OJRP1vVav42uU%3D&Expires=1288807041&AWSAccessKeyId=AKIAI3XHXJPFSJW2UQAQ HTTP/1.1" 206 4205237 "-" "WinampMPEG/5.56" 11
# EOF_OUTPUT

      expected_clf_log =<<EOF_OUTPUT
84.82.12.240 - 2cf7e6b06335c0689c6d29163df5bb001c96870cd78609e3845f1ed76a632621 [03/Nov/2010:15:57:29 +0000] "GET /10122150/2010-10-31-0930.mp3?Signature=5n2%2B8hrDvgSbP6OJRP1vVav42uU%3D&Expires=1288807041&AWSAccessKeyId=AKIAI3XHXJPFSJW2UQAQ HTTP/1.0" 200 4215272 "-" "WinampMPEG/5.56, Ultravox/2.1" 5
84.82.12.240 - 2cf7e6b06335c0689c6d29163df5bb001c96870cd78609e3845f1ed76a632621 [03/Nov/2010:15:57:34 +0000] "GET /10122150/2010-10-31-0930.mp3?Signature=5n2%2B8hrDvgSbP6OJRP1vVav42uU%3D&Expires=1288807041&AWSAccessKeyId=AKIAI3XHXJPFSJW2UQAQ HTTP/1.1" 206 144098 "-" "WinampMPEG/5.56" 4
84.82.12.240 - 2cf7e6b06335c0689c6d29163df5bb001c96870cd78609e3845f1ed76a632621 [03/Nov/2010:15:57:38 +0000] "GET /10122150/2010-10-31-0930.mp3?Signature=5n2%2B8hrDvgSbP6OJRP1vVav42uU%3D&Expires=1288807041&AWSAccessKeyId=AKIAI3XHXJPFSJW2UQAQ HTTP/1.1" 206 142454 "-" "WinampMPEG/5.56" 4
84.82.12.240 - 2cf7e6b06335c0689c6d29163df5bb001c96870cd78609e3845f1ed76a632621 [03/Nov/2010:15:57:42 +0000] "GET /10122150/2010-10-31-0930.mp3?Signature=5n2%2B8hrDvgSbP6OJRP1vVav42uU%3D&Expires=1288807041&AWSAccessKeyId=AKIAI3XHXJPFSJW2UQAQ HTTP/1.1" 206 139481 "-" "WinampMPEG/5.56" 3
84.82.12.240 - 2cf7e6b06335c0689c6d29163df5bb001c96870cd78609e3845f1ed76a632621 [03/Nov/2010:15:57:45 +0000] "GET /10122150/2010-10-31-0930.mp3?Signature=5n2%2B8hrDvgSbP6OJRP1vVav42uU%3D&Expires=1288807041&AWSAccessKeyId=AKIAI3XHXJPFSJW2UQAQ HTTP/1.1" 206 170111 "-" "WinampMPEG/5.56" 13
84.82.12.240 - 2cf7e6b06335c0689c6d29163df5bb001c96870cd78609e3845f1ed76a632621 [03/Nov/2010:15:57:58 +0000] "GET /10122150/2010-10-31-0930.mp3?Signature=5n2%2B8hrDvgSbP6OJRP1vVav42uU%3D&Expires=1288807041&AWSAccessKeyId=AKIAI3XHXJPFSJW2UQAQ HTTP/1.1" 206 141416 "-" "WinampMPEG/5.56" 3
84.82.12.240 - 2cf7e6b06335c0689c6d29163df5bb001c96870cd78609e3845f1ed76a632621 [03/Nov/2010:15:58:01 +0000] "GET /10122150/2010-10-31-0930.mp3?Signature=5n2%2B8hrDvgSbP6OJRP1vVav42uU%3D&Expires=1288807041&AWSAccessKeyId=AKIAI3XHXJPFSJW2UQAQ HTTP/1.1" 206 140120 "-" "WinampMPEG/5.56" 3
84.82.12.240 - 2cf7e6b06335c0689c6d29163df5bb001c96870cd78609e3845f1ed76a632621 [03/Nov/2010:15:58:04 +0000] "GET /10122150/2010-10-31-0930.mp3?Signature=5n2%2B8hrDvgSbP6OJRP1vVav42uU%3D&Expires=1288807041&AWSAccessKeyId=AKIAI3XHXJPFSJW2UQAQ HTTP/1.1" 206 138596 "-" "WinampMPEG/5.56" 3
84.82.12.240 - 2cf7e6b06335c0689c6d29163df5bb001c96870cd78609e3845f1ed76a632621 [03/Nov/2010:15:58:07 +0000] "GET /10122150/2010-10-31-0930.mp3?Signature=5n2%2B8hrDvgSbP6OJRP1vVav42uU%3D&Expires=1288807041&AWSAccessKeyId=AKIAI3XHXJPFSJW2UQAQ HTTP/1.1" 206 139070 "-" "WinampMPEG/5.56" 3
84.82.12.240 - 2cf7e6b06335c0689c6d29163df5bb001c96870cd78609e3845f1ed76a632621 [03/Nov/2010:15:58:10 +0000] "GET /10122150/2010-10-31-0930.mp3?Signature=5n2%2B8hrDvgSbP6OJRP1vVav42uU%3D&Expires=1288807041&AWSAccessKeyId=AKIAI3XHXJPFSJW2UQAQ HTTP/1.1" 206 150014 "-" "WinampMPEG/5.56" 6
84.82.12.240 - 2cf7e6b06335c0689c6d29163df5bb001c96870cd78609e3845f1ed76a632621 [03/Nov/2010:15:58:16 +0000] "GET /10122150/2010-10-31-0930.mp3?Signature=5n2%2B8hrDvgSbP6OJRP1vVav42uU%3D&Expires=1288807041&AWSAccessKeyId=AKIAI3XHXJPFSJW2UQAQ HTTP/1.1" 206 140423 "-" "WinampMPEG/5.56" 3
84.82.12.240 - 2cf7e6b06335c0689c6d29163df5bb001c96870cd78609e3845f1ed76a632621 [03/Nov/2010:15:58:19 +0000] "GET /10122150/2010-10-31-0930.mp3?Signature=5n2%2B8hrDvgSbP6OJRP1vVav42uU%3D&Expires=1288807041&AWSAccessKeyId=AKIAI3XHXJPFSJW2UQAQ HTTP/1.1" 206 140330 "-" "WinampMPEG/5.56" 3
84.82.12.240 - 2cf7e6b06335c0689c6d29163df5bb001c96870cd78609e3845f1ed76a632621 [03/Nov/2010:15:58:22 +0000] "GET /10122150/2010-10-31-0930.mp3?Signature=5n2%2B8hrDvgSbP6OJRP1vVav42uU%3D&Expires=1288807041&AWSAccessKeyId=AKIAI3XHXJPFSJW2UQAQ HTTP/1.1" 206 141713 "-" "WinampMPEG/5.56" 4
84.82.12.240 - 2cf7e6b06335c0689c6d29163df5bb001c96870cd78609e3845f1ed76a632621 [03/Nov/2010:15:58:26 +0000] "GET /10122150/2010-10-31-0930.mp3?Signature=5n2%2B8hrDvgSbP6OJRP1vVav42uU%3D&Expires=1288807041&AWSAccessKeyId=AKIAI3XHXJPFSJW2UQAQ HTTP/1.1" 206 131495 "-" "WinampMPEG/5.56" 0
84.82.12.240 - 2cf7e6b06335c0689c6d29163df5bb001c96870cd78609e3845f1ed76a632621 [03/Nov/2010:15:58:33 +0000] "GET /10122150/2010-10-31-0930.mp3?Signature=5n2%2B8hrDvgSbP6OJRP1vVav42uU%3D&Expires=1288807041&AWSAccessKeyId=AKIAI3XHXJPFSJW2UQAQ HTTP/1.1" 206 131870 "-" "WinampMPEG/5.56" 0
84.82.12.240 - 2cf7e6b06335c0689c6d29163df5bb001c96870cd78609e3845f1ed76a632621 [03/Nov/2010:15:58:37 +0000] "GET /10122150/2010-10-31-0930.mp3?Signature=5n2%2B8hrDvgSbP6OJRP1vVav42uU%3D&Expires=1288807041&AWSAccessKeyId=AKIAI3XHXJPFSJW2UQAQ HTTP/1.1" 206 131231 "-" "WinampMPEG/5.56" 0
84.82.12.240 - 2cf7e6b06335c0689c6d29163df5bb001c96870cd78609e3845f1ed76a632621 [03/Nov/2010:15:58:41 +0000] "GET /10122150/2010-10-31-0930.mp3?Signature=5n2%2B8hrDvgSbP6OJRP1vVav42uU%3D&Expires=1288807041&AWSAccessKeyId=AKIAI3XHXJPFSJW2UQAQ HTTP/1.1" 206 131294 "-" "WinampMPEG/5.56" 0
84.82.12.240 - 2cf7e6b06335c0689c6d29163df5bb001c96870cd78609e3845f1ed76a632621 [03/Nov/2010:15:58:44 +0000] "GET /10122150/2010-10-31-0930.mp3?Signature=5n2%2B8hrDvgSbP6OJRP1vVav42uU%3D&Expires=1288807041&AWSAccessKeyId=AKIAI3XHXJPFSJW2UQAQ HTTP/1.1" 206 131186 "-" "WinampMPEG/5.56" 0
84.82.12.240 - 2cf7e6b06335c0689c6d29163df5bb001c96870cd78609e3845f1ed76a632621 [03/Nov/2010:15:58:48 +0000] "GET /10122150/2010-10-31-0930.mp3?Signature=5n2%2B8hrDvgSbP6OJRP1vVav42uU%3D&Expires=1288807041&AWSAccessKeyId=AKIAI3XHXJPFSJW2UQAQ HTTP/1.1" 206 131354 "-" "WinampMPEG/5.56" 0
84.82.12.240 - 2cf7e6b06335c0689c6d29163df5bb001c96870cd78609e3845f1ed76a632621 [03/Nov/2010:15:58:51 +0000] "GET /10122150/2010-10-31-0930.mp3?Signature=5n2%2B8hrDvgSbP6OJRP1vVav42uU%3D&Expires=1288807041&AWSAccessKeyId=AKIAI3XHXJPFSJW2UQAQ HTTP/1.1" 206 142346 "-" "WinampMPEG/5.56" 4
84.82.12.240 - 2cf7e6b06335c0689c6d29163df5bb001c96870cd78609e3845f1ed76a632621 [03/Nov/2010:15:58:55 +0000] "GET /10122150/2010-10-31-0930.mp3?Signature=5n2%2B8hrDvgSbP6OJRP1vVav42uU%3D&Expires=1288807041&AWSAccessKeyId=AKIAI3XHXJPFSJW2UQAQ HTTP/1.1" 206 146744 "-" "WinampMPEG/5.56" 5
84.82.12.240 - 2cf7e6b06335c0689c6d29163df5bb001c96870cd78609e3845f1ed76a632621 [03/Nov/2010:15:59:00 +0000] "GET /10122150/2010-10-31-0930.mp3?Signature=5n2%2B8hrDvgSbP6OJRP1vVav42uU%3D&Expires=1288807041&AWSAccessKeyId=AKIAI3XHXJPFSJW2UQAQ HTTP/1.1" 206 148145 "-" "WinampMPEG/5.56" 6
84.82.12.240 - 2cf7e6b06335c0689c6d29163df5bb001c96870cd78609e3845f1ed76a632621 [03/Nov/2010:15:59:06 +0000] "GET /10122150/2010-10-31-0930.mp3?Signature=5n2%2B8hrDvgSbP6OJRP1vVav42uU%3D&Expires=1288807041&AWSAccessKeyId=AKIAI3XHXJPFSJW2UQAQ HTTP/1.1" 206 140993 "-" "WinampMPEG/5.56" 3
84.82.12.240 - 2cf7e6b06335c0689c6d29163df5bb001c96870cd78609e3845f1ed76a632621 [03/Nov/2010:15:59:09 +0000] "GET /10122150/2010-10-31-0930.mp3?Signature=5n2%2B8hrDvgSbP6OJRP1vVav42uU%3D&Expires=1288807041&AWSAccessKeyId=AKIAI3XHXJPFSJW2UQAQ HTTP/1.1" 206 163490 "-" "WinampMPEG/5.56" 11
EOF_OUTPUT

      output_log.string.should == expected_clf_log
      winamp_log.close
    end

    it "should mark invalid lines with '# ERROR: '" do
      $stderr = StringIO.new
      invalid_line = "this is an invalid log line"
      Ralf.translate_to_clf(invalid_line)
      $stderr.string.should eql("# ERROR: #{invalid_line}\n")
    end
    
    # it "should pass on reasonable 206 requests" do
    #   $stderr = StringIO.new
    #   reasonable_206_line = '2010-10-02-19-15-45-6879098C3140BE9D:2cf7e6b06335c0689c6d29163df5bb001c96870cd78609e3845f1ed76a632621 media.kerkdienstgemist.nl [02/Oct/2010:18:29:16 +0000] 82.168.113.55 2cf7e6b06335c0689c6d29163df5bb001c96870cd78609e3845f1ed76a632621 4F911681022807C6 REST.GET.OBJECT 10028050/2010-09-26-1830.mp3 "GET /10028050/2010-09-26-1830.mp3?Signature=E3ehd6nkXjNg7vr%2F4b3LtxCWads%3D&Expires=1286051333&AWSAccessKeyId=AKIAI3XHXJPFSJW2UQAQ HTTP/1.1" 206 - 4194304 17537676 500 12 "-" "VLC media player - version 1.0.5 Goldeneye - (c) 1996-2010 the VideoLAN team" -'
    #   Ralf.translate_to_clf(reasonable_206_line).should eql("82.168.113.55 - 2cf7e6b06335c0689c6d29163df5bb001c96870cd78609e3845f1ed76a632621 [02/Oct/2010:18:29:16 +0000] \"GET /10028050/2010-09-26-1830.mp3?Signature=E3ehd6nkXjNg7vr%2F4b3LtxCWads%3D&Expires=1286051333&AWSAccessKeyId=AKIAI3XHXJPFSJW2UQAQ HTTP/1.1\" 206 4194304 \"-\" \"VLC media player - version 1.0.5 Goldeneye - (c) 1996-2010 the VideoLAN team\" 1")
    #   $stderr.string.should be_empty
    # end

    # it "should mark unreasonably short 206 requests as such and leave them out of the result" do
    #   $stderr = StringIO.new
    #   unreasonable_206_line = '2010-10-02-19-15-45-6879098C3140BE9D:2cf7e6b06335c0689c6d29163df5bb001c96870cd78609e3845f1ed76a632621 media.kerkdienstgemist.nl [02/Oct/2010:18:29:16 +0000] 82.168.113.55 2cf7e6b06335c0689c6d29163df5bb001c96870cd78609e3845f1ed76a632621 4F911681022807C6 REST.GET.OBJECT 10028050/2010-09-26-1830.mp3 "GET /10028050/2010-09-26-1830.mp3?Signature=E3ehd6nkXjNg7vr%2F4b3LtxCWads%3D&Expires=1286051333&AWSAccessKeyId=AKIAI3XHXJPFSJW2UQAQ HTTP/1.1" 206 - 4194304 17537676 66 12 "-" "VLC media player - version 1.0.5 Goldeneye - (c) 1996-2010 the VideoLAN team" -'
    #   Ralf.translate_to_clf(unreasonable_206_line).should be_nil
    #   $stderr.string.should eql("# ERROR: unreasonable 206: #{unreasonable_206_line}\n")
    # end

    it "should add rounded total_time in seconds" do
      $stderr = StringIO.new
      input_line = '2010-10-02-19-15-45-6879098C3140BE9D:2cf7e6b06335c0689c6d29163df5bb001c96870cd78609e3845f1ed76a632621 media.kerkdienstgemist.nl [02/Oct/2010:18:29:16 +0000] 82.168.113.55 2cf7e6b06335c0689c6d29163df5bb001c96870cd78609e3845f1ed76a632621 4F911681022807C6 REST.GET.OBJECT 10028050/2010-09-26-1830.mp3 "GET /10028050/2010-09-26-1830.mp3?Signature=E3ehd6nkXjNg7vr%2F4b3LtxCWads%3D&Expires=1286051333&AWSAccessKeyId=AKIAI3XHXJPFSJW2UQAQ HTTP/1.1" 206 - 4194304 17537676 1600 12 "-" "VLC media player - version 1.0.5 Goldeneye - (c) 1996-2010 the VideoLAN team" -'
      Ralf.translate_to_clf(input_line).should eql("82.168.113.55 - 2cf7e6b06335c0689c6d29163df5bb001c96870cd78609e3845f1ed76a632621 [02/Oct/2010:18:29:16 +0000] \"GET /10028050/2010-09-26-1830.mp3?Signature=E3ehd6nkXjNg7vr%2F4b3LtxCWads%3D&Expires=1286051333&AWSAccessKeyId=AKIAI3XHXJPFSJW2UQAQ HTTP/1.1\" 206 135872 \"-\" \"VLC media player - version 1.0.5 Goldeneye - (c) 1996-2010 the VideoLAN team\" 2")
      $stderr.string.should be_empty
    end

  end
  
end
