require 'optparse'

class Ralf::OptionParser
  
  def self.parse(args, output = $stdout)
    options = {}

    opts = ::OptionParser.new do |opts|
      opts.banner = <<USAGE_END
Usage: #{$0} [options]

Download and merge Amazon S3 bucket log files for a specified date range and
output a Common Log File. Ralf is an acronym for Retrieve Amazon Log Files.

Ralf downloads bucket log files to local cache directories, merges the Amazon Log
Files and converts them to Common Log Format.

Example: #{$0} --range month --now yesterday --output-file '/var/log/amazon/:year/:month/:bucket.log'

AWS credentials (Access Key Id and Secret Access Key) are required to access
S3 buckets. For security reasons these credentials can only be specified in a
configuration file (see --config-file) or through the environment using the
AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY environment variables.
USAGE_END

      opts.separator ""
      opts.separator "Log selection options:"
      opts.on("-l", "--[no-]list", "List buckets that have logging enabled. Does not process log files.") do |value|
        options[:list] = value
      end
      opts.on("-b", "--buckets x,y,z", Array, "Buckets for which to process log files. Defaults to all log-enabled buckets.") do |buckets|
        options[:buckets] = buckets.compact
      end
      opts.on("-r", "--range BEGIN[,END]", Array, "Date or date range to process. Defaults to 'today'.") do |range|
        options[:range] = range.compact
      end
      log_selection_help =<<LOG_SELECTION_HELP
Date to use as base for range. Defaults to 'today'.

    You can use Chronic expressions for '--range' and '--now'. See http://chronic.rubyforge.org.
    
    Example: --range 'last week'
      All days of previous week.
    Example: --range 'this week'
      Beginning of this week (sunday) upto and including today.
    Example: --range '2010-01-01','2010-04-30'
      First four months of this year.
    Example: --range 'this month' --now yesterday
      This will select log files from the beginning of yesterday's month upto and including yesterday.

    The --buckets, --range and --now options are optional. If unspecified, (incomplete)
    logging for today will be processed for all buckets (that have logging enabled).
    This is equivalent to specifying "--range 'today'" and "--now 'today'".
LOG_SELECTION_HELP
      opts.on("-t", "--now TIME", log_selection_help) do |now|
        options[:now] = now
      end
      
      # opts.on("-m", "--[no-]rename-bucket-keys", "Rename original log files on Amazon using format from '--cache-dir' option.") do |value|
      #   options[:rename_bucket_keys] = value
      # end

      # opts.separator ""
      opts.separator "Output options:"

      output_file_help =<<OUTPUT_FILE_HELP
Output file, e.g. '/var/log/s3/:year/:month/:bucket.log'. Required.

    The --output-file format uses the last day of the range specified by (--range)
    to determine the filename. E.g. when the format contains ':year/:month/:day' and
    the range is 2010-01-15..2010-02-14, then the output file will be '2010/02/14'.
OUTPUT_FILE_HELP
      opts.on("-o", "--output-file FORMAT", output_file_help) do |format|
        options[:output_file] = format
      end
      
      cache_dir_help =<<CACHE_DIR_HELP
Directory name(s) in which to cache downloaded log files. Optional.

    The --cache-dir format expands to as many directory names as needed for the 
    range specified by --range. E.g. "/var/run/s3_cache/:year/:month/:day/:bucket"
    expands to 31 directories for range 2010-01-01..2010-01-31.
    
    Defaults to '~/.ralf/:bucket' or '/var/log/ralf/:bucket' (when running as root).
CACHE_DIR_HELP
      opts.on("-x", "--cache-dir FORMAT", cache_dir_help) do |format|
        options[:cache_dir] = format
      end

      # opts.on("-f", "--output-dir-format FORMAT", "Output directory format, e.g. ':year/:month/:day'") do |format|
      #   options[:output_dir_format] = format
      # end

      # opts.on("-o", "--output-basedir DIR", "Base directory for output files.") do |dir|
      #   options[:output_basedir] = dir
      # end

      # opts.on("-p", "--output-prefix STRING", "Prefix string for output files.") do |string|
      #   options[:output_prefix] = string
      # end
      
      # opts.separator ""
      opts.separator "Config file options:"
      config_file_help =<<CONFIG_FILE_HELP
Path to file with configuration settings (in YAML format).

    Configuration settings are read from the (-c) specified configuration file
    or from ~/.ralf.conf or from /etc/ralf.conf (when running as root).
    Command-line options override settings read from the configuration file.

    The configuration file must be in YAML format. Each command-line options has an
    equivalent setting in a configuration file replacing dash (-) by underscore(_).

    The Amazon Access Key Id and Secret Access Key can only be specified in the 

    Example:
      output_file:           /var/log/amazon_s3/:year:month/:bucket.log
      aws_access_key_id:     my_access_key_id
      aws_secret_access_key: my_secret_access_key

    To only use command-line options simply specify -c or --config-file without
    an argument.
CONFIG_FILE_HELP
      opts.on("-c", "--config-file [FILE]", config_file_help) do |file|
        options[:config_file] = file
      end
      
      opts.separator "Debug options:"
      opts.on("-d", "--[no-]debug [aws]", "Show debug messages.") do |aws|
        options[:debug] = aws || true
      end

      opts.separator ""
      opts.separator "Common options:"
      opts.on_tail("-h", "--help", "Show this message.") do
        output.puts opts
        return nil
      end
      opts.on_tail("-v", "--version", "Show version.") do
        output.print File.read(File.join(File.dirname(__FILE__), '..', '..', 'VERSION'))
        return nil
      end
    end
    remaining = opts.parse!(args)
    opts.warn "Warning: unused arguments: #{remaining.join(' ')}" unless remaining.empty?
    options
  end

end