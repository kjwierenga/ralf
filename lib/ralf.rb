require 'rubygems'
require 'right_aws'
require 'logmerge'
require 'ftools'
require 'ralf/interpolation'
require 'chronic'


# Parameters:
#   :config   a YAML config file, if none given it tries to open /etc/ralf.yaml or ~/.ralf.yaml
#   :date     the date to parse _or_
#   :range    a specific range as a string <start> (wicht creates a range to now) or array: [<start>] _or_ [<start>,<stop>]
#             (examples: 'today'; 'yesterday'; 'january'; ['2 days ago', 'yesterday']; )
#   (note:  When :range is supplied it takes precendence over :date)
# 
# These params are also config params (supplied in the params hash, they take precedence over the config file)
#   :aws_access_key_id      (required in config)
#   :aws_secret_access_key  (required in config)
#   :out_path               (required in config)
#   :out_prefix             (optional, defaults to 's3_combined')
#   :out_seperator          (optional, defaults to '') specify directory seperators (e.g. ':year/:month/:day')
#   :organize_originals     (boolean, optional) organize asset on S3 in the same structure as :out_seperator
#                           (WARNING: there is an extra performance and cost penalty)

# 
# If the required params are given then there is no need to supply a config file
# 

class Ralf
  class NoConfigFile < StandardError ; end
  class ConfigIncomplete < StandardError ; end
  class InvalidDate < StandardError ; end

  DEFAULT_PREFERENCES = ['/etc/ralf.yaml', '~/.ralf.yaml']
  ROOT = File.expand_path(File.join(File.dirname(__FILE__), ".."))
  AMAZON_LOG_FORMAT = Regexp.new('([^ ]*) ([^ ]*) \[([^\]]*)\] ([^ ]*) ([^ ]*) ([^ ]*) ([^ ]*) ([^ ]*) "([^"]*)" ([^ ]*) ([^ ]*) ([^ ]*) ([^ ]*) ([^ ]*) ([^ ]*) "([^"]*)" "([^"]*)"')

  attr :date
  attr :range
  attr :config
  attr_reader :s3, :buckets_with_logging

  def initialize(args = {})
    @buckets_with_logging = []

    if args[:range]
      self.range = args.delete(:range)
    else
      self.date = args.delete(:date)
    end

    read_preferences(args.delete(:config), args)

    @s3 = RightAws::S3.new(@config[:aws_access_key_id], @config[:aws_secret_access_key]) 

  end

  def self.run(*args)
    ralf = Ralf.new(*args)
    ralf.run
  end

  def run
    find_buckets_with_logging
    puts @buckets_with_logging.collect {|buc| buc.logging_info.inspect } if ENV['DEBUG']
    @buckets_with_logging.each do |bucket|
      save_logging(bucket)
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

  def save_logging(bucket)
    if @range
      range.each do |day|
        @date = day
        save_logging_to_local_disk(bucket, day)
      end
    else
      save_logging_to_local_disk(bucket, date)
    end
  end

  # Saves files to disk if they do not exists yet
  def save_logging_to_local_disk(bucket, for_date)

    if bucket.name != bucket.logging_info[:targetbucket]
      puts "logging for '%s' is on '%s'" % [bucket.name, bucket.logging_info[:targetbucket]] if ENV['DEBUG']
      targetbucket = @s3.bucket(bucket.logging_info[:targetbucket])
    else
      targetbucket = bucket
    end

    search_string = "%s%s" % [bucket.logging_info[:targetprefix], for_date]

    targetbucket.keys(:prefix => search_string).each do |key|

      File.makedirs(local_log_dirname(bucket))
      local_log_file = File.expand_path(File.join(local_log_dirname(bucket), local_log_file_basename(bucket, key)))

      unless File.exists?(local_log_file)
        puts "Writing #{local_log_file}" if ENV['DEBUG']
        File.open(local_log_file, 'w') { |f| f.write(key.data) }
      else
        puts "File exists #{local_log_file}" if ENV['DEBUG']
      end

      if @config[:organize_originals]
        puts "moving #{key.name} to #{s3_organized_log_file(bucket, key)}" if ENV['DEBUG']
        key.move(s3_organized_log_file(bucket, key))
      end
    end
  end

  # merge all files just downloaded for date to 1 combined file
  def merge_to_combined(bucket)
    in_files = Dir.glob(File.join(local_log_dirname(bucket), "#{local_log_file_basename_prefix(bucket)}#{date}*"))
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

  def s3_organized_log_file(bucket, key)
    File.join(log_dir(bucket).gsub(bucket.name + '/',''), out_seperator, local_log_file_basename(bucket, key))
  end

  def date
    "%4d-%02d-%02d" % [@date.year, @date.month, @date.day] 
  end

  def date=(date)
    if date && ! date.nil?
      time = Chronic.parse(date, :context => :past )
      if time 
        @date = Date.parse(time.strftime('%Y-%m-%d'))
      else
        raise Ralf::InvalidDate, "#{date} is an invalid value."
      end
    else
      @date = Date.today
    end
  end

  def range
    Range.new(
      Date.new(@range[:from].year, @range[:from].month, @range[:from].day),
      Date.new(@range[:till].year, @range[:till].month, @range[:till].day)
    )
  end

  def range=(range)
    if range.is_a?(Array)
      @range = {
        :from => Chronic.parse(range[0], :context => :past),
        :till => Chronic.parse(range[1], :context => :past) || Date.today
      }
    elsif range.is_a?(String) # when it's a string it can be a specific date or a period (like month)
      begin
        date = Date.strptime(range)
        @range = { :from => date, :till => Date.today }
      rescue # date raises an error
        time = Chronic.parse(range, :context => :past, :guess => false)
        if time.width > (3600 * 24) # this is a period
          @range = { :from => time.begin, :till => time.end.utc }
        else
          @range = { :from => time.begin, :till => Date.today }
        end
      end
    else
      raise Ralf::InvalidDate, "#{range} is an invalid value."
    end
  end

  # Create a dynamic output folder
  def out_seperator
    if @config[:out_seperator]
      Ralf::Interpolation.interpolate(@date, @config[:out_seperator])
    else
      ''
    end
  end

  def out_seperator=(out_seperator)
    @config[:out_seperator] = out_seperator
  end

  def translate_to_clf(line)
    if line =~ AMAZON_LOG_FORMAT
      # host, date, ip, acl, request, status, bytes, agent = $2, $3, $4, $5, $9, $10, $12, $17
      "%s - %s [%s] \"%s\" %d %s \"%s\" \"%s\"" % [$4, $5, $3, $9, $10, $12, $16, $17]
    else
      "# ERROR: #{line}"
    end
  end

  def log_dir(bucket)
    if bucket.logging_info[:targetprefix] =~ /\/$/
      log_dir = "%s/%s" % [bucket.name, bucket.logging_info[:targetprefix].gsub(/\/$/,'')]
    else
      log_dir = File.dirname("%s/%s" % [bucket.name, bucket.logging_info[:targetprefix]])
    end
    log_dir
  end

  # locations of files for this bucket and date
  def local_log_dirname(bucket)
    File.expand_path(File.join(@config[:out_path], log_dir(bucket), out_seperator))
  end

  def local_log_file_basename(bucket, key)
    "%s%s" % [local_log_file_basename_prefix(bucket), key.name.gsub(bucket.logging_info[:targetprefix], '')]
  end

  def local_log_file_basename_prefix(bucket)
    return '' if bucket.logging_info[:targetprefix] =~ /\/$/
    bucket.logging_info[:targetprefix].split('/').last
  end

protected

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
