require 'rubygems'
require 'optparse'

class Ralf::OptionParser
  
  def self.parse(args, output = $stdout)
    options = {}

    opts = ::OptionParser.new do |opts|
      opts.banner = "Usage: #{$0} [options]

Download, merge and convert Amazon S3 log files for a specified date or date range.

ralf reads options from '~/.ralf.yaml' or '/etc/ralf.yaml'. These files must be in YAML format.

Example:
  out_path:          /var/log/amazon_s3
  log_file:          /var/log/ralf.log
  aws_access_key_id: my_secret_key_id

Command line options override the options loaded from the configuration file."

      opts.separator ""
      opts.separator "Specific options:"

      opts.on("-r", "--range BEGIN[,END]", Array, "Date or date range to process. Supports Chronic expressions (http://chronic.rubyforge.org)") do |range|
        options[:range] = range.compact
      end

      opts.on("-t", "--now TIME", "Date to use as base range off. Supports Chronic expressions (http://chronic.rubyforge.org)") do |now|
        options[:now] = now
      end

      opts.separator ""
      opts.separator "Output options:"
      opts.on("-f", "--output-dir-format FORMAT", "Output directory format, e.g. ':year/:month/:day'") do |format|
        options[:output_dir_format] = format
      end

      opts.on("-d", "--output-basedir DIR", "Base directory for output files") do |dir|
        options[:output_basedir] = dir
      end

      opts.on("-p", "--output-prefix STRING", "Prefix string for output files") do |string|
        options[:output_prefix] = string
      end
      
      opts.on("-l", "--[no-]list-buckets", "List buckets that have logging enabled") do |value|
        options[:list_buckets] = value
      end
      
      opts.on("-b", "--buckets x,y,z", Array, "List of buckets for which to process logfiles") do |buckets|
        options[:buckets] = buckets.compact
      end
      
      opts.separator ""
      opts.separator "Amazon options:"
      opts.on("-a", "--aws-access-key-id AWS_ACCESS_KEY_ID",
              "AWS Access Key Id") do |aws_access_key_id|
        options[:aws_access_key_id] = aws_access_key_id
      end
      opts.on("-s", "--aws-secret-access-key AWS_SECRET_ACCESS_KEY",
              "AWS Secret Access Key") do |aws_secret_access_key|
        options[:aws_secret_access_key] = aws_secret_access_key
      end
      opts.on("-m", "--[no-]rename-bucket-keys", "Rename original log files on Amazon using '--output-dir-format' option") do |value|
        options[:rename_bucket_keys] = value
      end

      opts.separator ""
      opts.separator "Config file options:"
      opts.on("-c", "--config-file FILE", "Path to configuration file (.yaml)") do |file|
        options[:config_file] = file
      end

      opts.separator ""
      opts.separator "Log options:"
      opts.on("-e", "--log-file FILE", "Path to log file") do |file|
        options[:log_file] = file
      end

      opts.separator ""
      opts.separator "Common options:"
      opts.on_tail("-h", "--help", "Show this message") do
        output.puts opts
        return nil
      end
      opts.on_tail("--version", "Show version") do
        puts ::OptionParser::Version.join('.')
        return nil
      end
    end
    remaining = opts.parse!(args)
    opts.warn "Warning: unused arguments: #{remaining.join(' ')}" unless remaining.empty?
    options
  end

end