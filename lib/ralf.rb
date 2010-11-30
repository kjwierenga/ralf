require 'rubygems'
require 'right_aws'
require 'logmerge'
require 'ftools'
require 'ralf/config'
require 'ralf/bucket'
require 'chronic'
require 'stringio'
require 'date'

class Ralf

  private
  RLIMIT_NOFILE_HEADROOM = 100 # number of file descriptors to allocate above number of logfiles

  public

  ROOT_DEFAULT_CONFIG_FILE = '/etc/ralf.conf'
  USER_DEFAULT_CONFIG_FILE = '~/.ralf.conf'

  AMAZON_LOG_FORMAT = Regexp.new('([^ ]*) ([^ ]*) \[([^\]]*)\] ([^ ]*) ([^ ]*) ([^ ]*) ([^ ]*) ([^ ]*) "([^"]*)" ([^ ]*) ([^ ]*) ([^ ]*) ([^ ]*) ([^ ]*) ([^ ]*) "([^"]*)" "([^"]*)"')
  AMAZON_LOG_FORMAT_COPY = Regexp.new('([^ ]*) ([^ ]*) \[([^\]]*)\] ([^ ]*) ([^ ]*) ([^ ]*) (REST.COPY.OBJECT_GET) ([^ ]*) (-) ([^ ]*) (-) (-) ([^ ]*) (-) (-) (-) (-) (-)')
  
  # The current configuration.
  attr_reader :config
  
  # Instance of RightAws::S3 used by Ralf to talk to Amazon S3.
  attr_reader :s3
  
  # Create instance and run with the specified parameters
  def self.run(options)
    list = options.delete(:list)

    ralf = Ralf.new(options)
    if list
      ralf.list
    else
      ralf.run
    end
  end
  
  # Create new Ralf instance
  def initialize(options = {})
    initial_options = options.dup

    @config = load_config(initial_options.delete(:config_file))
    
    config.merge!(initial_options)
    config.validate!
    
    RightAws::RightAwsBaseInterface.caching = true # enable caching to speed up
    Bucket.s3 = RightAws::S3.new(config.aws_access_key_id, config.aws_secret_access_key,
      :protocol => 'http', :port => 80,
      :logger => Logger.new('aws' == config.debug? ? $stdout : StringIO.new)
    )
  end

  # For all buckets for all dates in the configured range download the available
  # log files. After downloading, merge the log files and convert the format
  # from Amazon Log Format to Apache Common Log Format.
  def run(output_file = nil)
    config.output_file = output_file unless output_file.nil?
    
    raise ArgumentError.new("--output-file required") if config.output_file_missing?
    raise ArgumentError.new("--output-file requires ':bucket' variable") if (config.buckets.nil? || config.buckets.size > 1) and !(config.output_file_format =~ /:bucket/)
    
    puts "Processing range #{config.range}" if config.debug?

    # iterate over all buckets
    Bucket.each(config.buckets) do |bucket|
      
      print "#{bucket.name}: " if config.debug?

      # iterate over the full range
      log_files = []
      config.range.each do |date|
        dir = config.cache_dir(:bucket => bucket.name, :date => date)
        log_files << Ralf.download_logs(bucket, date, dir)
      end
      log_files.flatten!

      # determine output file names
      output_log = config.output_file(:date => config.range.end, :bucket => bucket.name)
      merged_log =  output_log + ".alf"

      # create directory for output file
      File.makedirs(File.dirname(merged_log))

      # merge the log files
      Ralf.merge(merged_log, log_files)
      
      # convert to common log format
      Ralf.convert_to_common_log_format(merged_log, output_log)

      puts "#{log_files.size} files" if config.debug?
    end
  end
  
  # List all buckets with the logging info.
  def list(with_logging = false)
    puts "Listing buckets..." if config.debug?
    
    Bucket.each(config.buckets, with_logging) do |bucket|
      print "#{bucket.name}"
      puts bucket.logging_enabled? ? " [#{bucket.targetbucket}/#{bucket.targetprefix}]" : " [-]"
    end

    nil
  end

  private
  
  # Download log files for +bucket+ and +date+ to +dir+.
  def self.download_logs(bucket, date, dir)
    File.makedirs(dir)

    # iterate over the available log files, saving them to disk and 
    log_files = []
    bucket.each_log(date) do |log|
      log_files << log.save_to_dir(dir)
    end
    log_files
  end
  
  # Takes an array of log file names and merges them on ascending timestamp
  # into +output_file+ name. Assumes the +log_files+ are sorted
  # on ascending timestamp.
  def self.merge(output_file, log_files)
    update_rlimit_nofile(log_files.size)
    File.open(output_file, 'w') do |out_file|
      LogMerge::Merger.merge out_file, *log_files
    end
  end

  # Convert the input_log file to Apache Common Log Format into output_log
  def self.convert_to_common_log_format(input_log, output_log)
    out_file = File.open(output_log, 'w')
    File.open(input_log, 'r') do |in_file|
      while (line = in_file.gets)
        if clf = translate_to_clf(line)
          out_file.puts(clf)
        end
      end
    end
    out_file.close
  end

  def self.translate_to_clf(line)
    if line =~ AMAZON_LOG_FORMAT
      if 206 == $10.to_i && ($12.to_i > 3*1024*1024) && ($12.to_i < 500)
        $stderr.puts "# ERROR: unreasonable 206: #{line}"
        nil
      else
        # host, date, ip, acl, request, status, bytes, agent = $2, $3, $4, $5, $9, $10, $12, $17
        "%s - %s [%s] \"%s\" %d %s \"%s\" \"%s\"" % [$4, $5, $3, $9, $10, $12, $16, $17]
      end
    elsif line =~ AMAZON_LOG_FORMAT_COPY
      "%s - %s [%s] \"%s\" %d %s \"%s\" \"REST.COPY.OBJECT_GET\"" % [$4, $5, $3, "POST /#{$8} HTTP/1.1", $10, $12, $16]
    else
      $stderr.puts "# ERROR: #{line}"
      nil
    end
  end

  def load_config(cli_config_file)
    result = nil
    if cli_config_file
      result = Ralf::Config.load_file(cli_config_file) unless cli_config_file.empty?
    else
      config_file = (0 == Process.uid ? ROOT_DEFAULT_CONFIG_FILE : File.expand_path(USER_DEFAULT_CONFIG_FILE))
      result = Ralf::Config.load_file(config_file) if File.exist?(config_file)
    end
    result || Ralf::Config.new
  end
  
  def self.update_rlimit_nofile(number_of_files)
    new_rlimit_nofile = number_of_files + RLIMIT_NOFILE_HEADROOM

    # getrlimit returns array with soft and hard limit [soft, hard]
    rlimit_nofile = Process::getrlimit(Process::RLIMIT_NOFILE)
    if new_rlimit_nofile > rlimit_nofile.first
      Process.setrlimit(Process::RLIMIT_NOFILE, new_rlimit_nofile) rescue nil
    end 
  end
  
end
