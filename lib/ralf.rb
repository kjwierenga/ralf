require 'rubygems'
require 'right_aws'
require 'logmerge'
require 'ftools'
require 'ralf/interpolation'

class Ralf
  class NoConfigFile < StandardError ; end
  class ConfigIncomplete < StandardError ; end

  DEFAULT_PREFERENCES = ['/etc/ralf.yaml', '~/.ralf.yaml']
  ROOT = File.expand_path(File.join(File.dirname(__FILE__), ".."))
  AMAZON_LOG_FORMAT = Regexp.new('([^ ]*) ([^ ]*) \[([^\]]*)\] ([^ ]*) ([^ ]*) ([^ ]*) ([^ ]*) ([^ ]*) "([^"]*)" ([^ ]*) ([^ ]*) ([^ ]*) ([^ ]*) ([^ ]*) ([^ ]*) "([^"]*)" "([^"]*)"')

  attr :date
  attr :config
  attr_reader :s3, :buckets_with_logging

  # Parameters:
  #   :config   a YAML config file, if none given it tries to open /etc/ralf.yaml or ~/.ralf.yaml
  #   :date     the date to parse
  # 
  # These params are also config params (supplied in the params hash, they take precedence over the config file)
  #   :aws_access_key_id      (required in config)
  #   :aws_secret_access_key  (required in config)
  #   :out_path               (required in config)
  #   :out_prefix             (optional, defaults to 's3_combined')
  #   :out_seperator          (optional, defaults to nil) c.q. do we split directories
  # 
  # If the required params are given then there is no need to supply a config file
  def initialize(args = {})
    @buckets_with_logging = []

    self.date = args.delete(:date)

    read_preferences(args.delete(:config), args)

    @s3 = RightAws::S3.new(@config[:aws_access_key_id], @config[:aws_secret_access_key]) 

  end

  def self.run(*args)
    ralf = Ralf.new(*args)
    ralf.run
  end

  def run
    find_buckets_with_logging
    @buckets_with_logging.each do |bucket|
      save_logging_to_disk(bucket)
      merge_to_combined(bucket)
      convert_alt_to_clf(bucket)
    end
  end

  # Finds all buckets (in scope of provided credentials) which have logging enabled
  def find_buckets_with_logging
    @s3.buckets.each do |bucket|
      logging_params = bucket.logging_info
      if logging_params[:enabled]
        @buckets_with_logging << bucket
      end
    end
  end

  # Saves files to disk if they do not exists yet
  def save_logging_to_disk(bucket)
    bucket.keys(:prefix => "%s%s" % [bucket.logging_info[:targetprefix], date]).each do |key|
      File.makedirs(local_log_dirname(bucket))
      log_file = File.expand_path(File.join(local_log_dirname(bucket), local_log_file_basename(bucket, key)))
      if File.exists?(log_file)
        puts "File exists #{log_file}" if ENV['DEBUG']
      else
        puts "Writing #{log_file}" if ENV['DEBUG']
        File.open(log_file, 'w') { |f| f.write(key.data) }
      end
    end
  end

  # merge all files just downloaded for date to 1 combined file
  def merge_to_combined(bucket)
    in_files = Dir.glob(log_globber(bucket, date))
    File.open(File.join(@config[:out_path], output_alf_file_name(bucket)), 'w') do |out_file|
      LogMerge::Merger.merge out_file, *in_files
    end
  end

  # Convert Amazon log files to Apache CLF
  def convert_alt_to_clf(bucket)
    out_file = File.open(File.join(@config[:out_path], output_clf_file_name(bucket)), 'w')
    File.open(File.join(@config[:out_path], output_alf_file_name(bucket)), 'r') do |in_file|
      while (line = in_file.gets)
        out_file.puts(translate_to_clf(line))
      end
    end
    out_file.close
  end

  def date
    "%4d-%02d-%02d" % [@date.year, @date.month, @date.day] 
  end

  def date=(date)
    if date
      @date = Date.strptime(date)
    else
      @date = Date.today
    end
  end

  def translate_to_clf(line)
    if line =~ AMAZON_LOG_FORMAT
      # host, date, ip, acl, request, status, bytes, agent = $2, $3, $4, $5, $9, $10, $12, $17
      "%s - %s [%s] \"%s\" %d %s \"%s\" \"%s\"" % [$4, $5, $3, $9, $10, $12, $16, $17]
    else
      "# ERROR: #{line}"
    end
  end

  def local_log_file_basename(bucket, key)
    "%s%s" % [bucket.logging_info[:targetprefix].split('/').last, key.name.gsub(bucket.logging_info[:targetprefix], '')]
  end

  # locations of files for this bucket and date
  def local_log_dirname(bucket)
    if bucket.logging_info[:targetprefix] =~ /\/$/
      log_dir = "%s/%s" % [bucket.name, bucket.logging_info[:targetprefix].gsub(/\/$/,'')]
    else
      log_dir = File.dirname("%s/%s" % [bucket.name, bucket.logging_info[:targetprefix]])
    end
    File.expand_path(File.join(@config[:out_path], log_dir, out_seperator))
  end

  # Create a dynamic output folder
  #  ex:  Ralf.new(:out_seperator => ':year/:month/:day')
  def out_seperator
    if @config[:out_seperator]
      Ralf::Interpolation.interpolate(@date, @config[:out_seperator])
    else
      ''
    end
  end

protected

  def log_globber(bucket, globber)
    "%s/%s/%s%s*" % [@config[:out_path], bucket.name, bucket.logging_info[:targetprefix], globber]
  end

  def output_alf_file_name(bucket)
    "%s_%s_%s.alf" % [@config[:out_prefix] || "s3_combined", bucket.name, date]
  end

  def output_clf_file_name(bucket)
    "%s_%s_%s.log" % [@config[:out_prefix] || "s3_combined", bucket.name, date]
  end

  def read_preferences(config_file, params = {})
    unless config_file
      DEFAULT_PREFERENCES.each do |file|
        expanded_file = File.expand_path( file ) 
        if File.exists?( expanded_file )
          config_file = expanded_file
        end
      end
    end

    if config_file && File.exists?( File.expand_path(config_file) )
      @config = YAML.load_file( File.expand_path(config_file) ).merge(params)
    elsif params.size > 0
      @config = params
    else
      raise NoConfigFile, "There is no config file defined for Ralf."
    end

    raise ConfigIncomplete unless (
      (@config[:aws_access_key_id]     || ENV['AWS_ACCESS_KEY_ID']) &&
      (@config[:aws_secret_access_key] || ENV['AWS_SECRET_ACCESS_KEY']) &&
      @config[:out_path]
    )
  end

end
