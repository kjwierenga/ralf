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
  # :config   a YAML config file, if none given it tries to open /etc/ralf.yaml or ~/.ralf.yaml
  # :date     the date to parse
  # 
  def initialize(args = {})
    @buckets_with_logging = []
    @config = {}

    read_preferences(args.delete(:config))

    self.date = args.delete(:date)

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

  # Save files to disk if they do not exists yet
  def save_logging_to_disk(bucket)
    bucket.keys(:prefix => "%s%s" % [bucket.logging_info[:targetprefix], @date]).each do |key|
      File.makedirs(File.expand_path(File.join(ROOT, "tmp", "s3", bucket.name)))
      log_file = File.expand_path(File.join(ROOT, "tmp", "s3", bucket.name, key.name.gsub(bucket.logging_info[:targetprefix],"")))
      if File.exists?(log_file)
        puts "File exists #{log_file}"
      else
        puts "Writing #{log_file}"
        File.open(log_file, 'w') { |f| f.write(key.data) }
      end
    end
  end

  def merge_to_combined(bucket)
    puts "Merging!"
    File.expand_path(File.join(ROOT, "tmp", "s3", bucket.name))
    in_files = Dir.glob(File.join(ROOT, "tmp", "s3", bucket.name, "*"))
    out_file = File.open(File.join(ROOT, "tmp", "s3", "s3_combined_#{bucket.name}_#{@date}.ALF"), 'w')
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
  def read_preferences(config_file)
    unless config_file
      DEFAULT_PREFERENCES.each do |file|
        if File.exists?( file )
          config_file = file
        end
      end
    end

    if config_file && File.exists?(config_file)
      @config = YAML.load_file( config_file )
    else
      raise NoConfigFile, "There is no config file defined for Ralf."
    end

    raise ConfigIncomplete unless (@config[:aws_access_key_id] && @config[:aws_secret_access_key] && @config[:out_path])
  end
end
