require "ralf/version"
require 'ralf/interpolation'
require "ralf/bucket_processor"
require "ralf/clf_translator"
require "ralf/clf_time"
require 'right_aws'
require 'yaml'

class Ralf
  class InvalidConfig < StandardError ; end

  attr_reader :config
  attr_reader :s3

  # required parameters:
  #  :cache_dir  => './cache',
  #  :output_dir => './logs/:year/:month/:day',
  #  :days_to_look_back => 5, # proces N days
  #  :days_to_ignore => 2,    # ignore N days
  #  :aws_key    => '--AWS_KEY--',
  #  :aws_secret => '--AWS_SECTRET--',
  #  :log_bucket => "logbucket1",
  #  :log_prefix => 'logs/'
  def config=(hash)
    @config = symbolize_keys(hash)
    validate_config
  end

  def read_config_from_file(file)
    self.config = YAML::load(File.open(file))
  end

  def validate_config
    raise InvalidConfig.new("No config set") if config.nil?
    errors = []
    [:cache_dir, :output_dir, :days_to_look_back, :days_to_ignore, :aws_key, :aws_secret, :log_bucket, :log_prefix].each do |c|
      errors << c if config[c].nil?
    end
    errors << "Cache dir does not exixst" if config[:cache_dir] && ! File.exist?(config[:cache_dir])
    if errors.size > 0
      raise InvalidConfig.new("Required options: '#{errors.join("', '")}'")
    end
  end

  def initialize_s3
    RightAws::RightAwsBaseInterface.caching = true # enable caching to speed up
    @s3 = RightAws::S3.new(
      config[:aws_key],
      config[:aws_secret],
      # :protocol => 'http',
      # :port => 80,
      :logger => Logger.new($stdout)
    )
  end

  def process_log_bucket
    bucket = BucketProcessor.new(s3.bucket(config[:log_bucket]), self)
    bucket.process
  end

private

  def symbolize_keys(hash)
    hash.inject({}){|memo,(k,v)| memo[k.to_sym] = v; memo}
  end

end
