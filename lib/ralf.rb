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

  def read_config(file)
    @config = symbolize_keys(YAML::load(File.open(file)))
  end

  def validate_config
    raise InvalidConfig.new("No config set") if config.nil?
    errors = []
    [:cache_dir, :output_dir, :range_size, :aws_key, :aws_secret, :log_buckets, :log_prefix].each do |c|
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

  def iterate_and_process_log_buckets
    config[:log_buckets].each do |log_bucket|
      bucket = BucketProcessor.new(s3.bucket(log_bucket), self)
      bucket.process
    end
  end

private

  def symbolize_keys(hash)
    hash.inject({}){|memo,(k,v)| memo[k.to_sym] = v; memo}
  end

end
