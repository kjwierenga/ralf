require 'rubygems'
require 'right_aws'
require 'logmerge'
require 'ftools'
require 'ralf/config'
require 'ralf/bucket'
require 'chronic'

class Ralf

  CONFIG_FILE_PATHS = [ '~/.ralf.conf', '/etc/ralf.conf' ]
  AMAZON_LOG_FORMAT = Regexp.new('([^ ]*) ([^ ]*) \[([^\]]*)\] ([^ ]*) ([^ ]*) ([^ ]*) ([^ ]*) ([^ ]*) "([^"]*)" ([^ ]*) ([^ ]*) ([^ ]*) ([^ ]*) ([^ ]*) ([^ ]*) "([^"]*)" "([^"]*)"')
  
  RLIMIT_NOFILE_HEADROOM = 100 # number of file descriptors to allocate above number of logfiles
  
  attr_reader :config
  attr_reader :s3 #, :buckets_with_logging
  attr_reader :buckets
  
  def self.run(params)
    list = params.delete(:list)

    ralf = Ralf.new(params)
    if list
      ralf.list
    else
      ralf.run
    end
  end
  
  def initialize(args = {})
    params = args.dup

    @config = read_cli_or_default_config(params.delete(:config_file), CONFIG_FILE_PATHS)
    
    config.merge!(params)
    config.validate!
    
    RightAws::RightAwsBaseInterface.caching = true # enable caching to speed up
    Bucket.s3 = RightAws::S3.new(config.aws_access_key_id, config.aws_secret_access_key,
      :protocol => 'http', :port => 80,
      :logger => Logger.new('aws' == config.debug? ? $stdout : StringIO.new)
    )
  end
  
  def run(output_file = nil)
    config.output_file = output_file unless output_file.nil?
    
    raise ArgumentError.new("--output-file required") if config.output_file_missing?
    
    # iterate over all buckets
    Bucket.each(config.buckets) do |bucket|

      # iterate over the full range
      config.range.each do |date|

        cache_dir_for_date = config.cache_dir(:date => date, :bucket => bucket.name)
        File.makedirs(cache_dir_for_date)

        # iterate over the available log files, saving them to disk and 
        log_files = []
        bucket.each_log(date) do |log|
          log_files << log.save_to_dir(cache_dir_for_date)
        end
        
        # merge the log files
        output_log = config.output_file(:date => config.range.end, :bucket => bucket.name)
        merged_log =  output_log + ".alf"
        merge(log_files, merged_log)
        
        # convert to common log format
        convert_to_common_log_format(merged_log, output_log)
      end
    end
  end
  
  def merge(log_files, output_file)
    print "Merging #{log_files.size} files..." if config.debug?

    update_rlimit_nofile(log_files.size)
    File.open(output_file, 'w') do |out_file|
      LogMerge::Merger.merge out_file, *log_files
    end

    puts "done." if config.debug?
  end

  def convert_to_common_log_format(merged_log, output_log)
    print "Converting to Common Log Format..." if config.debug?
    
    out_file = File.open(output_log, 'w')
    File.open(merged_log, 'r') do |in_file|
      while (line = in_file.gets)
        out_file.puts(translate_to_clf(line))
      end
    end
    out_file.close
    
    puts "done." if config.debug?
  end
  
  # list buckets
  def list(with_logging = false)
    puts "Listing buckets..." if config.debug?
    
    Bucket.each(config.buckets, with_logging) do |bucket|
      print "#{bucket.name}"
      puts bucket.logging_enabled? ? " [#{bucket.targetbucket}/#{bucket.targetprefix}]" : " [-]"
    end

    nil
  end
  
  private
  
  def translate_to_clf(line)
    if line =~ AMAZON_LOG_FORMAT
      # host, date, ip, acl, request, status, bytes, agent = $2, $3, $4, $5, $9, $10, $12, $17
      "%s - %s [%s] \"%s\" %d %s \"%s\" \"%s\"" % [$4, $5, $3, $9, $10, $12, $16, $17]
    else
      $stderr.puts "# ERROR: #{line}"
    end
  end
  
  # public
  # 
  # 
  # def run
  #   puts "Processing: #{range.begin == range.end ? range.begin : range}" if config.debug?
  #   
  #   @buckets_with_logging = find_buckets_with_logging(config.buckets)
  # 
  #   @buckets_with_logging.each do |b|
  #     logging_info = bucket.logging_info
  #     puts "#{bucket.name} logging to #{logging_info[:targetbucket]}/#{logging_info[:targetprefix]}"
  #   end if config.debug?
  # 
  #   @buckets_with_logging.each do |bucket|
  #     save_logging(bucket)
  #     merge_to_combined(bucket)
  #     convert_alf_to_clf(bucket)
  #   end
  # end
  # 
  # def list(names)
  #   puts "Listing buckets..." if config.debug?
  #   
  #   find_buckets(names).each do |bucket|
  #     logging_info = bucket.logging_info
  #     print "#{bucket.name}"
  #     puts logging_info[:enabled] ? " [#{logging_info[:targetbucket]}/#{logging_info[:targetprefix]}]" : " [-]"
  #   end
  # end
  # 
  # # Finds all buckets (in scope of provided credentials)
  # def find_buckets(names, with_logging = false)
  #   # find specified buckets
  #   if names
  #     names.map do |name|
  #       bucket = returning @s3.bucket(name) do |bucket|
  #         puts("Warning: bucket '#{name}' not found.") if bucket.nil?
  #       end
  #       bucket = nil if bucket.logging_info
  #     end.compact # remove nils i.e. buckets not found
  #   else
  #     @s3.buckets
  #   end
  # end
  # 
  # # Find buckets with logging enabled
  # def find_buckets_with_logging(names = nil)
  #   buckets = find_buckets(names)
  # 
  #   # remove buckets that don't have logging enabled
  #   buckets.map do |bucket|
  #     bucket.logging_info[:enabled] ? bucket : nil
  #   end.compact # remove nils, i.e. buckets without logging
  #   @buckets_with_logging = buckets
  # end
  # 
  # def save_logging(bucket)
  #   logging_info = bucket.logging_info
  #   range.each do |date|
  #     save_logging_to_local_disk(bucket, logging_info, date)
  #   end
  # end
  # 
  # # Saves files to disk if they do not exists yet
  # def save_logging_to_local_disk(bucket, logging_info, date)
  # 
  #   if bucket.name != logging_info[:targetbucket]
  #     puts "logging for '%s' is on '%s'" % [bucket.name, logging_info[:targetbucket]] if config.debug?
  #     targetbucket = @s3.bucket(logging_info[:targetbucket])
  #   else
  #     targetbucket = bucket
  #   end
  # 
  #   File.makedirs(local_log_dirname(bucket.name, logging_info[:targetprefix]))
  # 
  #   search_string = "%s%s" % [logging_info[:targetprefix], date]
  #   targetbucket.keys(:prefix => search_string).each do |key|
  # 
  #     local_log_file = File.expand_path(File.join(
  #       local_log_dirname(bucket.name, logging_info[:targetprefix]),
  #       local_log_file_basename(logging_info[:targetprefix], key.name)))
  # 
  #     unless File.exists?(local_log_file)
  #       puts "Writing #{local_log_file}" if config.debug?
  #       File.open(local_log_file, 'w') { |f| f.write(key.data) }
  #     else
  #       puts "File exists #{local_log_file}" if config.debug?
  #     end
  # 
  #     # if config[:rename_bucket_keys]
  #     #   puts "moving #{key.name} to #{s3_organized_log_file(bucket.name, logging_info[:targetprefix], key)}" if config.debug?
  #     #   key.move(s3_organized_log_file(bucket.name, logging_info[:targetprefix], key))
  #     # end
  #   end
  # end
  # 
  # # merge all files just downloaded for date to 1 combined file
  # def merge_to_combined(bucket)
  #   puts "Merging..." if config.debug?
  #   
  #   logging_info = bucket.logging_info
  #   in_files = []
  #   range.each do |date|
  #     in_files += Dir.glob(File.join(local_log_dirname(bucket.name, logging_info[:targetprefix]), "#{local_log_file_basename_prefix(logging_info[:targetprefix])}#{date}*"))
  #   end
  # 
  #   update_rlimit_nofile(in_files.size)
  # 
  #   File.open(config.output_file(range.end, bucket.name) + ".alf", 'w') do |out_file|
  #     LogMerge::Merger.merge out_file, *in_files
  #   end
  # end
  # 
  # # Convert Amazon log files to Apache CLF
  # def convert_alf_to_clf(bucket)
  #   puts "Convert to CLF..." if config.debug?
  #   
  #   out_file = File.open(config.output_file(range.end, bucket.name), 'w')
  #   File.open(config.output_file(range.end, bucket.name) + ".alf", 'r') do |in_file|
  #     while (line = in_file.gets)
  #       out_file.puts(translate_to_clf(line))
  #     end
  #   end
  #   out_file.close
  # end
  # 
  # def s3_organized_log_file(bucket_name, targetprefix, key)
  #   File.join(log_dir(bucket_name, targetprefix).gsub(bucket_name + '/',''), output_dir_format, local_log_file_basename(targetprefix, key))
  # end
  # 
  # # Create a dynamic output folder
  # def output_dir_format
  #   # TODO: should this be range.begin, or range.end or should the separator
  #   # be interpolated for each logfile?
  #   if config[:output_dir_format]
  #     Ralf::Interpolation.interpolate(range.end, config[:output_dir_format])
  #   else
  #     ''
  #   end
  # end
  # 
  # def output_dir_format=(output_dir_format)
  #   config[:output_dir_format] = output_dir_format
  # end
  # 
  # 
  # def log_dir(bucket_name, targetprefix)
  #   if targetprefix =~ /\/$/
  #     log_dir = "%s/%s" % [bucket_name, targetprefix.gsub(/\/$/,'')]
  #   else
  #     log_dir = File.dirname("%s/%s" % [bucket_name, targetprefix])
  #   end
  #   log_dir
  # end
  # 
  # # locations of files for this bucket and date
  # def local_log_dirname(bucket_name, targetprefix)
  #   File.expand_path(File.join(config[:output_basedir], log_dir(bucket_name, targetprefix), output_dir_format))
  # end
  # 
  # def local_log_file_basename(targetprefix, key_name)
  #   "%s%s" % [local_log_file_basename_prefix(targetprefix), key_name.gsub(targetprefix, '')]
  # end
  # 
  # def local_log_file_basename_prefix(targetprefix)
  #   return '' if targetprefix =~ /\/$/
  #   targetprefix.split('/').last
  # end

private

  def read_cli_or_default_config(cli_config_file, default_config_files)
    config = nil
    if cli_config_file
      config = Ralf::Config.load_file(cli_config_file) unless cli_config_file.empty?
    else
      default_config_files.each do |file|
        file = File.expand_path(file)
        next unless File.exist?(file)
        break if config = Ralf::Config.load_file(file)
      end
    end
    config || Ralf::Config.new
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
