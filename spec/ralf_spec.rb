require File.dirname(__FILE__) + '/spec_helper'

require 'ralf'

CONFIG_PATH      = File.expand_path(File.dirname(__FILE__) + '/fixtures/config.yaml')
FULL_CONFIG_PATH = File.expand_path(CONFIG_PATH)
CONFIG_YAML      = YAML.load_file(FULL_CONFIG_PATH)

describe Ralf do

  before(:all) do
    @key1 = {:name => 'log/access_log-2010-02-10-00-05-32-ZDRFGTCKUYVJCT', :data => 'This is content for key 1'}
    @key2 = {:name => 'log/access_log-2010-02-10-00-07-28-EFREUTERGRSGDH', :data => 'This is content for key 2'}
    @key3 = {:name => 'log/access_log-2010-02-11-00-09-32-SDHTFTFHDDDDDH', :data => 'This is content for key 3'}
    
    @default_params = {
      :config => CONFIG_PATH,
      :out_seperator => ':year/:month/:day',
      :date => '2010-02-10'
    }
    
    # File = mock('File')
  end

  before(:each) do
    # TODO find out why next line only behaves as expected in before(:each)
    # it should really work OK in before(:all)
    RightAws::S3.should_receive(:new).any_number_of_times.and_return(mock('RightAws::S3'))
  end

  describe "Preferences" do

    it "should initialize properly" do
      config_file_expectations
      
      ralf = Ralf.new(@default_params)
      ralf.class.should eql(Ralf)
    end
  
    it "should raise an error when an nonexistent config file is given" do
      non_existing_file_name = '~/a_non_existent_file.yaml'
      non_existing_file_name_path = '/Test/Users/test_user/a_non_existent_file.yaml'
      File.should_receive(:expand_path).with(non_existing_file_name).and_return(non_existing_file_name_path)
      File.should_receive(:exists?).with(non_existing_file_name_path).and_return(false)

      lambda {
        ralf = Ralf.new(:config => non_existing_file_name)
      }.should raise_error(Ralf::NoConfigFile)
    end

    it "should set the preferences" do
      config_file_expectations

      ralf = Ralf.new(@default_params)
      ralf.config[:aws_access_key_id].should     eql('access_key')
      ralf.config[:aws_secret_access_key].should eql('secret')
      ralf.config[:out_path].should              eql('/Test/Users/test_user/S3')
      # ralf.config.should eql({:aws_access_key_id => 'access_key', :aws_secret_access_key => 'secret'})
    end

    it "should look for default configurations" do
      log_file = '/var/log/ralf.log'
      File.should_receive(:expand_path).once.with(log_file).and_return(log_file)
      File.stub(:open).and_return(StringIO.new)

      
      YAML.should_receive(:load_file).with('/Test/Users/test_user/.ralf.yaml').and_return({
        'aws_access_key_id'      => 'access_key',
        'aws_secret_access_key'  => 'secret',
        'out_path'               => '/Test/Users/test_user/S3',
        'out_prefix'             => 's3_combined'
      })
      File.should_receive(:expand_path).once.with('~/.ralf.yaml').and_return('/Test/Users/test_user/.ralf.yaml')
      File.should_receive(:expand_path).twice.with('/Test/Users/test_user/.ralf.yaml').and_return('/Test/Users/test_user/.ralf.yaml')
      File.should_receive(:expand_path).once.with('/etc/ralf.yaml').and_return('/etc/ralf.yaml')
      File.should_receive(:expand_path).once.with('/Test/Users/test_user/S3').and_return('/Test/Users/test_user/S3')
      File.should_receive(:exists?).once.with('/etc/ralf.yaml').and_return(false)
      File.should_receive(:exists?).twice.with('/Test/Users/test_user/.ralf.yaml').and_return(true)

      ralf = Ralf.new()
    end

    it "should use AWS credentials provided in ENV" do
      ENV['AWS_ACCESS_KEY_ID']     = 'access_key'
      ENV['AWS_SECRET_ACCESS_KEY'] = 'secret'

      [ [ '/etc/ralf.yaml'] * 2,
        [ '~/.ralf.yaml', '/Test/Users/test_user/.ralf.yaml' ] ].each do |paths|
        File.should_receive(:expand_path).once.ordered.with(paths.first).and_return(paths.last)
        File.should_receive(:exists?).once.ordered.with(paths.last).and_return(false)
      end

      lambda {
        Ralf.new(:out_path => '/Test/Users/test_user/S3')
      }.should_not raise_error(Ralf::ConfigIncomplete)

    end

  end

  describe "Date handling" do
    
    it "should set the date to today" do
      config_file_expectations
      ralf = Ralf.new(@default_params.merge(:date => nil))
      date = Date.today
      ralf.date.should  eql("%4d-%02d-%02d" % [date.year, date.month, date.day])
    end

    it "should set the date to the date given" do
      config_file_expectations
      ralf = Ralf.new(@default_params.merge(:date => '2010-02-01'))
      ralf.date.should  eql('2010-02-01')
    end

    it "should raise error when invalid date given" do
      lambda {
        ralf = Ralf.new(@default_params.merge(:date => 'someday'))
        ralf.date.should  be_nil
      }.should raise_error(Ralf::InvalidDate, "someday is an invalid value.")
    end

    it "should accept a range of 2 dates" do
      config_file_expectations
      ralf = Ralf.new(@default_params.merge(:date => nil, :range => ['2010-02-10', '2010-02-12']))
      ralf.range.to_s.should eql('2010-02-10..2010-02-12')
    end

    it "should accept a range starting with 1 date" do
      config_file_expectations
      Date.should_receive(:today).any_number_of_times.and_return(Date.strptime('2010-02-17'))
      ralf = Ralf.new(@default_params.merge(:date => nil, :range => '2010-02-10'))
      ralf.range.to_s.should eql('2010-02-10..2010-02-17')

      config_file_expectations
      ralf = Ralf.new(@default_params.merge(:date => nil, :range => ['2010-02-10']))
      ralf.range.to_s.should eql('2010-02-10..2010-02-17')
    end

    it "should accept a range defined by words" do
      Date.should_receive(:today).any_number_of_times.and_return(Date.strptime('2010-02-17'))
      Chronic.should_receive(:parse).once.with('2 days ago', {:guess=>false, :context=>:past}).and_return(
        Chronic::Span.new(Time.parse('Mon Feb 15 00:00:00 +0100 2010'),Time.parse('Tue Feb 16 00:00:00 +0100 2010'))
      )

      config_file_expectations
      ralf = Ralf.new(@default_params.merge(:date => nil, :range => '2 days ago'))
      ralf.range.to_s.should eql('2010-02-15..2010-02-17')
    end

    it "should accept a month and convert it to a range" do
      config_file_expectations
      ralf = Ralf.new(@default_params.merge(:date => nil, :range => 'january'))
      ralf.range.to_s.should  eql('2010-01-01..2010-01-31')
    end

  end

  describe "Handle Buckets" do

    before(:each) do
      config_file_expectations
      
      @ralf = Ralf.new(@default_params)
      @bucket1 = {:name => 'bucket1'}
      @bucket1.should_receive(:logging_info).any_number_of_times.and_return({ :enabled => true, :targetprefix => "log/access_log-", :targetbucket => @bucket1[:name] })
      @bucket1.should_receive(:name).any_number_of_times.and_return(@bucket1[:name])
      @bucket2 = {:name => 'bucket2'}
      @bucket2.should_receive(:logging_info).any_number_of_times.and_return({ :enabled => false, :targetprefix => "log/", :targetbucket => @bucket2[:name] })
      @bucket2.should_receive(:name).any_number_of_times.and_return(@bucket2[:name])
    end

    it "should find buckets with logging enabled" do
      @ralf.s3.should_receive(:buckets).once.and_return([@bucket1, @bucket2])

      @ralf.find_buckets_with_logging.should  eql([@bucket1, @bucket2])
      @ralf.buckets_with_logging.should       eql([@bucket1])
    end

    it "should return the new organized path" do
      File.should_receive(:dirname).with("bucket1/log/access_log-").and_return('bucket1/log')
      File.should_receive(:join) { |*args| args.join('/') }
      
      @key1.should_receive(:name).and_return(@key1[:name])
      @ralf.s3_organized_log_file(@bucket1, @key1).should eql('log/2010/02/10/access_log-2010-02-10-00-05-32-ZDRFGTCKUYVJCT')
    end

    describe "logging" do

      before(:each) do
        @key1.should_receive(:name).any_number_of_times.and_return(@key1[:name])
        @key2.should_receive(:name).any_number_of_times.and_return(@key2[:name])
        @key1.should_receive(:data).any_number_of_times.and_return(@key1[:data])
        @key2.should_receive(:data).any_number_of_times.and_return(@key2[:data])
      end

      it "should save logging to disk" do
        @bucket1.should_receive(:keys).any_number_of_times.and_return([@key1, @key2])

        dir = '/Test/Users/test_user/S3/bucket1/log/2010/02/10'
        file1 = "#{dir}/access_log-2010-02-10-00-05-32-ZDRFGTCKUYVJCT"
        file2 = "#{dir}/access_log-2010-02-10-00-07-28-EFREUTERGRSGDH"
        File.should_receive(:makedirs).twice.with(dir).and_return(true)
        File.should_receive(:exists?).once.with(file1).and_return(true)
        File.should_receive(:exists?).once.with(file2).and_return(false)
        File.should_receive(:open).once.with(   file2, "w").and_return(true)

        File.should_receive(:dirname).any_number_of_times.with("bucket1/log/access_log-").and_return('bucket1/log')

        [ dir, file1, file2 ].each do |path|
          File.should_receive(:expand_path).any_number_of_times.with(path).and_return(path)
        end

        @ralf.save_logging_to_local_disk(@bucket1, '2010-02-10').should eql([@key1, @key2])
      end

      it "should save logging for range to disk" do
        pending "TODO: fix this spec" do
          @bucket1.should_receive(:keys).any_number_of_times.and_return([@key1, @key2], [@key3], [])
          @key3.should_receive(:name).any_number_of_times.and_return(@key3[:name])
          @key3.should_receive(:data).any_number_of_times.and_return(@key3[:data])

          @ralf.date = nil
          @ralf.range = ['2010-02-10', '2010-02-12']

          dir1 = '/Test/Users/test_user/S3/bucket1/log/2010/02/10'
          dir2 = '/Test/Users/test_user/S3/bucket1/log/2010/02/11'
          File.should_receive(:exists?).once.with('#{dir1}/access_log-2010-02-10-00-05-32-ZDRFGTCKUYVJCT').and_return(false)
          File.should_receive(:exists?).once.with('#{dir1}/access_log-2010-02-10-00-07-28-EFREUTERGRSGDH').and_return(true)
          File.should_receive(:exists?).once.with('#{dir2}/access_log-2010-02-11-00-09-32-SDHTFTFHDDDDDH').and_return(false)
          File.should_receive(:open).once.with(   '#{dir1}/access_log-2010-02-10-00-05-32-ZDRFGTCKUYVJCT', "w").and_return(true)
          File.should_receive(:open).once.with(   '#{dir2}/access_log-2010-02-11-00-09-32-SDHTFTFHDDDDDH', "w").and_return(true)

          File.should_receive(:dirname).with("bucket1/log/access_log-").and_return('bucket1/log')
          File.should_receive(:expand_path).any_number_of_times { |dir| dir }
          File.should_receive(:dirname).with('/Test/Users/test_user/S3/bucket1/log/2010/02/10').and_return('/Test/Users/test_user/S3/bucket1/log/2010/02')

          @ralf.save_logging(@bucket1).class.should  eql(Range)
        end
      end

      it "should save logging if a different targetbucket is given" do
        pending "TODO: fix this spec" do
          @ralf.s3.should_receive(:bucket).and_return(@bucket1)
          @bucket3 = {:name => 'bucket3'}
          @bucket3.should_receive(:logging_info).any_number_of_times.and_return({ :enabled => false, :targetprefix => "log/", :targetbucket => 'bucket1' })
          @bucket3.should_receive(:name).any_number_of_times.and_return(@bucket3[:name])
          @bucket1.should_receive(:keys).any_number_of_times.and_return([@key1, @key2])

          File.should_receive(:expand_path).with('/Test/Users/test_user/S3/bucket3/log/2010/02/10').and_return('/Test/Users/test_user/S3/bucket3/log/2010/02/10')
          File.should_receive(:join) { |*args| args.join('/') }

          @ralf.save_logging_to_local_disk(@bucket3, '2010-02-10').should eql([@key1, @key2])
        end
      end

    end

    it "should merge all logs" do
      out_string = StringIO.new

      Dir.should_receive(:glob).with('/Test/Users/test_user/S3/bucket1/log/2010/02/10/access_log-2010-02-10*').and_return(
          ['/Test/Users/test_user/S3/bucket1/log/2010/02/10/access_log-2010-02-10-00-05-32-ZDRFGTCKUYVJCT',
           '/Test/Users/test_user/S3/bucket1/log/2010/02/10/access_log-2010-02-10-00-07-28-EFREUTERGRSGDH'])

      File.should_receive(:open).with('/Test/Users/test_user/S3/s3_combined_bucket1_2010-02-10.alf', "w").and_yield(out_string)

      LogMerge::Merger.should_receive(:merge).with(
        out_string, 
        '/Test/Users/test_user/S3/bucket1/log/2010/02/10/access_log-2010-02-10-00-05-32-ZDRFGTCKUYVJCT',
        '/Test/Users/test_user/S3/bucket1/log/2010/02/10/access_log-2010-02-10-00-07-28-EFREUTERGRSGDH'
      )

      File.should_receive(:dirname).with("bucket1/log/access_log-").and_return('bucket1/log')
      File.should_receive(:join).any_number_of_times { |*args| args.join('/') }
      
      File.should_receive(:expand_path).with('/Test/Users/test_user/S3/bucket1/log/2010/02/10').and_return('/Test/Users/test_user/S3/bucket1/log/2010/02/10')

      @ralf.merge_to_combined(@bucket1)

      out_string.string.should eql('')
    end

    it "should save logs which have a targetprefix containing a '/'" do
      File.should_receive(:dirname).with("bucket1/log/access_log-").and_return('bucket1/log')
      
      bucket1_path = '/Test/Users/test_user/S3/bucket1/log/2010/02/10'
      bucket2_path = '/Test/Users/test_user/S3/bucket2/log/2010/02/10'
      [ bucket1_path, bucket2_path ].each do |path|
        File.should_receive(:expand_path).once.ordered.with(path).and_return(path)
      end

      @ralf.local_log_dirname(@bucket1).should  eql(bucket1_path)
      @ralf.local_log_dirname(@bucket2).should  eql(bucket2_path)
    end

    it "should save to a subdir when a out_seperator is given" do
      path1 = '/Test/Users/test_user/S3/bucket1/log/2010/02/10'
      File.should_receive(:expand_path).once.with(path1).and_return(path1)

      @ralf.local_log_dirname(@bucket1).should  eql(path1)

      path2 = '/Test/Users/test_user/S3/bucket1/log/2010/w06'
      File.should_receive(:expand_path).once.with(path2).and_return(path2)

      @ralf.out_seperator = ':year/w:week'
      @ralf.local_log_dirname(@bucket1).should  eql(path2)
    end

    it "should get the proper directories" do
      File.should_receive(:expand_path).with('/Test/Users/test_user/S3/bucket1/log/2010/02/10').and_return('/Test/Users/test_user/S3/bucket1/log/2010/02/10')
      File.should_receive(:join).any_number_of_times { |*args| args.join('/') }
      
      @key1.should_receive(:name).and_return('log/access_log-2010-02-10-00-05-32-ZDRFGTCKUYVJCT')
      @ralf.local_log_file_basename_prefix(@bucket1).should   eql('access_log-')
      @ralf.local_log_file_basename(@bucket1, @key1).should   eql('access_log-2010-02-10-00-05-32-ZDRFGTCKUYVJCT')
      @ralf.local_log_dirname(@bucket1).should                eql('/Test/Users/test_user/S3/bucket1/log/2010/02/10')

      @key1.should_receive(:name).and_return('log/2010-02-10-00-05-32-ZDRFGTCKUYVJCT')
      @ralf.local_log_file_basename_prefix(@bucket2).should   eql('')
      @ralf.local_log_file_basename(@bucket2, @key1).should   eql('2010-02-10-00-05-32-ZDRFGTCKUYVJCT')

      path = '/Test/Users/test_user/S3/bucket2/log/2010/02/10'
      File.should_receive(:expand_path).once.with(path).and_return(path)
      @ralf.local_log_dirname(@bucket2).should eql(path)
    end

  end

  describe "Conversion" do

    before(:each) do
      config_file_expectations
      
      @ralf    = Ralf.new(@default_params)
      @bucket1 = {:name => 'bucket1'}
      @bucket1.should_receive(:name).any_number_of_times.and_return('bucket1')
    end

    it "should convert the alf to clf" do
      File.should_receive(:open).once.with("/Test/Users/test_user/S3/s3_combined_bucket1_2010-02-10.log", "w").and_return(File)
      File.should_receive(:open).once.with("/Test/Users/test_user/S3/s3_combined_bucket1_2010-02-10.alf", "r").and_return(File)
      File.should_receive(:close).once.and_return(true)

      File.should_receive(:join).any_number_of_times { |*args| args.join('/') }

      @ralf.convert_alt_to_clf(@bucket1).should eql(true)
    end

    it "should find the proper values in a line" do
      [ [
        '2cf7e6b06335c0689c6d29163df5bb001c96870cd78609e3845f1ed76a632621 assets.staging.kerkdienstgemist.nl [10/Feb/2010:07:17:01 +0000] 10.32.219.38 3272ee65a908a7677109fedda345db8d9554ba26398b2ca10581de88777e2b61 784FD457838EFF42 REST.GET.ACL - "GET /?acl HTTP/1.1" 200 - 1384 - 399 - "-" "Jakarta Commons-HttpClient/3.0" -                        ',
        '10.32.219.38 - 3272ee65a908a7677109fedda345db8d9554ba26398b2ca10581de88777e2b61 [10/Feb/2010:07:17:01 +0000] "GET /?acl HTTP/1.1" 200 1384 "-" "Jakarta Commons-HttpClient/3.0"'
      ],[
        '2cf7e6b06335c0689c6d29163df5bb001c96870cd78609e3845f1ed76a632621 assets.staging.kerkdienstgemist.nl [10/Feb/2010:07:17:02 +0000] 10.32.219.38 3272ee65a908a7677109fedda345db8d9554ba26398b2ca10581de88777e2b61 6E239BC5A4AC757C SOAP.PUT.OBJECT logs/2010-02-10-07-17-02-F6EFD00DAB9A08B6 "POST /soap/ HTTP/1.1" 200 - 797 686 63 31 "-" "Axis/1.3" -',
        '10.32.219.38 - 3272ee65a908a7677109fedda345db8d9554ba26398b2ca10581de88777e2b61 [10/Feb/2010:07:17:02 +0000] "POST /soap/ HTTP/1.1" 200 797 "-" "Axis/1.3"'
      ],[
        '2cf7e6b06335c0689c6d29163df5bb001c96870cd78609e3845f1ed76a632621 assets.staging.kerkdienstgemist.nl [10/Feb/2010:07:24:40 +0000] 10.217.37.15 - 0B76C90B3634290B REST.GET.ACL - "GET /?acl HTTP/1.1" 307 TemporaryRedirect 488 - 7 - "-" "Jakarta Commons-HttpClient/3.0" -                                                                          ',
        '10.217.37.15 - - [10/Feb/2010:07:24:40 +0000] "GET /?acl HTTP/1.1" 307 488 "-" "Jakarta Commons-HttpClient/3.0"'
      ] ].each do |alf,clf|
        @ralf.translate_to_clf(alf).should eql(clf)
      end
    end

    it "should mark invalid lines with '# ERROR: '" do
      @ralf.translate_to_clf('An invalid line in the logfile').should match(/^# ERROR/)
    end

  end
  
  def config_file_expectations
    File.should_receive(:expand_path).twice.with(CONFIG_PATH).and_return(FULL_CONFIG_PATH)
    File.should_receive(:exists?).once.with(FULL_CONFIG_PATH).and_return(true)
    File.should_receive(:open).once.and_return(CONFIG_YAML)
  end

end
