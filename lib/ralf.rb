require 'rubygems'
require 'right_aws'
require 'logmerge'
require 'ftools'

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
  # 
  # If the required params are given then there is no need to supply a config file
  def initialize(args = {})
    @buckets_with_logging = []

    self.date = args.delete(:date)

    read_preferences(args.delete(:config), args)

    @s3 = RightAws::S3.new(@config[:aws_access_key_id], @config[:aws_secret_access_key]) 

    find_buckets_with_logging

    # @buckets_with_logging.each  do |bucket|
    #   save_logging_to_disk(bucket)
    #   merge_to_combined(bucket)
    # end
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
      File.makedirs(File.expand_path(File.join(@config[:out_path], bucket.name, bucket.logging_info[:targetprefix])))
      log_file = File.expand_path(File.join(@config[:out_path], bucket.name, key.name))
      if File.exists?(log_file)
        puts "File exists #{log_file}"
      else
        puts "Writing #{log_file}"
        File.open(log_file, 'w') { |f| f.write(key.data) }
      end
    end
  end

  # merge all files just downloaded for date to 1 combined file
  def merge_to_combined(bucket)
    in_files = Dir.glob( File.join(@config[:out_path], bucket.name, bucket.logging_info[:targetprefix], "#{date}*"))
    out_file = File.open(File.join(@config[:out_path], output_file_name(bucket)), 'w')
    LogMerge::Merger.merge out_file, *in_files
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

protected
  def output_file_name(bucket)
    "%s_%s_%s.alf" % [@config[:out_prefix] || "s3_combined", bucket.name, date]
  end

  def read_preferences(config_file, params = {})
    unless config_file
      DEFAULT_PREFERENCES.each do |file|
        if File.exists?( file )
          config_file = file
        end
      end
    end

    if config_file && File.exists?(config_file)
      @config = YAML.load_file( config_file ).merge(params)
    elsif params.size > 0
      @config = params
    else
      raise NoConfigFile, "There is no config file defined for Ralf."
    end

    raise ConfigIncomplete unless (
      @config[:aws_access_key_id] &&
      @config[:aws_secret_access_key] &&
      @config[:out_path]
    )
  end
end
