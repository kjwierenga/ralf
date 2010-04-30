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
#   :out_separator          (optional, defaults to '') specify directory separators (e.g. ':year/:month/:day')
#   :organize_originals     (boolean, optional) organize asset on S3 in the same structure as :out_separator
#                           (WARNING: there is an extra performance and cost penalty)

# 
# If the required params are given then there is no need to supply a config file
# 

class Ralf
  class NoConfigFile     < StandardError ; end
  class ConfigIncomplete < StandardError ; end
  class InvalidRange     < StandardError ; end

  DEFAULT_PREFERENCES = [ '/etc/ralf.yaml', '~/.ralf.yaml' ]
  ROOT = File.expand_path(File.join(File.dirname(__FILE__), ".."))
  AMAZON_LOG_FORMAT = Regexp.new('([^ ]*) ([^ ]*) \[([^\]]*)\] ([^ ]*) ([^ ]*) ([^ ]*) ([^ ]*) ([^ ]*) "([^"]*)" ([^ ]*) ([^ ]*) ([^ ]*) ([^ ]*) ([^ ]*) ([^ ]*) "([^"]*)" "([^"]*)"')
  
  RLIMIT_NOFILE_HEADROOM = 100 # number of file descriptors to allocate above number of logfiles

  # attr :date
  # attr :range
  attr :config
  attr_reader :s3, :buckets_with_logging

  def initialize(args = {})
    @buckets_with_logging = []

    params = args.dup
    self.range = params.delete(:range)

    read_preferences(params.delete(:config), params)

    log_file = File.open(File.expand_path(@config[:log_file] || '/var/log/ralf.log'),
                         File::WRONLY | File::APPEND | File::CREAT)
    @s3 = RightAws::S3.new(
            @config[:aws_access_key_id],
            @config[:aws_secret_access_key],
            { :logger => Logger.new(log_file) })
  end

  def self.run(params)
    ralf = Ralf.new(params)
    ralf.run
  end

  def run
    STDOUT.puts "Processing: #{range.begin == range.end ? range.begin : range}"
    
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
    range.each do |date|
      save_logging_to_local_disk(bucket, date)
    end
  end

  # Saves files to disk if they do not exists yet
  def save_logging_to_local_disk(bucket, date)

    if bucket.name != bucket.logging_info[:targetbucket]
      puts "logging for '%s' is on '%s'" % [bucket.name, bucket.logging_info[:targetbucket]] if ENV['DEBUG']
      targetbucket = @s3.bucket(bucket.logging_info[:targetbucket])
    else
      targetbucket = bucket
    end

    search_string = "%s%s" % [bucket.logging_info[:targetprefix], date]

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
    in_files = []
    range.each do |date|
      in_files += Dir.glob(File.join(local_log_dirname(bucket), "#{local_log_file_basename_prefix(bucket)}#{date}*"))
    end

    update_rlimit_nofile(in_files.size)
    
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
    File.join(log_dir(bucket).gsub(bucket.name + '/',''), out_separator, local_log_file_basename(bucket, key))
  end

  def range
    raise ArgumentError unless 2 == @range.size
    Range.new(time_to_date(@range.first), time_to_date(@range.last)) # inclusive
  end
  
  def range=(args)
    args ||= []
    args = [args] unless args.is_a?(Array)

    range = []
    args.each_with_index do |expr, i|
      raise Ralf::InvalidRange, "unused extra argument '#{expr}'" if i > 1
      if span = Chronic.parse(expr, :context => :past, :guess => false)
        if is_more_than_a_day?(span)
          raise Ralf::InvalidRange, "range end '#{expr}' is not a single date" if i > 0
          range << span.begin
          range << span.end - 1
        else
          range << span.begin
        end
      else
        raise Ralf::InvalidRange, "invalid expression '#{expr}'"
      end
    end
    
    range = [ Date.today ] if range.empty? # empty range means today
    range = range*2 if 1 == range.size     # single day has begin == end
    
    @range = range
  end
  
  def is_more_than_a_day?(span)
    span.width > 24 * 3600
  end
  
  # Create a dynamic output folder
  def out_separator
    # TODO: should this be range.begin, or range.end or should the separator
    # be interpolated for each logfile?
    if @config[:out_separator]
      Ralf::Interpolation.interpolate(range.end, @config[:out_separator])
    else
      ''
    end
  end

  def out_separator=(out_separator)
    @config[:out_separator] = out_separator
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
    File.expand_path(File.join(@config[:out_path], log_dir(bucket), out_separator))
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
    "%s_%s_%s.alf" % [@config[:out_prefix] || "s3_combined", bucket.name, range.end]
  end

  def output_clf_file_name(bucket)
    "%s_%s_%s.log" % [@config[:out_prefix] || "s3_combined", bucket.name, range.end]
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
      @config = YAML.load_file( File.expand_path(config_file) )
      
      # define symbolize_keys! method on the instance to convert key strings to symbols
      def @config.symbolize_keys!; h = self.dup; self.clear; h.each_pair { |k,v| self[k.to_sym] = v }; self; end

      @config.symbolize_keys!
      @config.merge!(params)
    elsif params.size > 0
      @config = params
    else
      raise NoConfigFile, "There is no config file defined for Ralf."
    end
    
    @config[:out_path] = File.expand_path(@config[:out_path])

    raise ConfigIncomplete unless (
      (@config[:aws_access_key_id]     || ENV['AWS_ACCESS_KEY_ID']) &&
      (@config[:aws_secret_access_key] || ENV['AWS_SECRET_ACCESS_KEY']) &&
      @config[:out_path]
    )
  end
  
private
  
  def time_to_date(time)
    Date.new(time.year, time.month, time.day)
  end

  def update_rlimit_nofile(number_of_files)
    new_rlimit_nofile = number_of_files + RLIMIT_NOFILE_HEADROOM

    # getrlimit returns array with soft and hard limit [soft, hard]
    rlimit_nofile = Process::getrlimit(Process::RLIMIT_NOFILE)
    if new_rlimit_nofile > rlimit_nofile.first
      Process.setrlimit(Process::RLIMIT_NOFILE, new_rlimit_nofile) rescue nil
    end 
  end

end
