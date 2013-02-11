require 'ralf/interpolation'
require 'yaml'

class Ralf::Config
  
  USER_DEFAULT_CACHE_DIR = '~/.ralf/:bucket'
  ROOT_DEFAULT_CACHE_DIR = '/var/log/ralf/:bucket'
  
  class ConfigurationError < StandardError ; end
  class RangeError         < StandardError ; end

  attr_accessor \
    :buckets,
    :now,
    # :range,
    :aws_access_key_id,
    :aws_secret_access_key
    
  attr_writer \
    :debug,       # reader is debug?
    :output_file, # reader interpolates format
    :cache_dir    # reader interpolates format
    
  attr_reader :errors
  attr_reader :translate_options
  
  protected
  
  attr_accessor :options
  
  public

  def self.load_file(filepath)
    self.new(YAML.load_file(filepath))
  end

  def initialize(options = {})
    @options = options.dup
    
    # assign defaults
    @options[:now]       ||= nil
    @options[:range]     ||= 'today'
    @options[:cache_dir] ||= (0 == Process.uid ? ROOT_DEFAULT_CACHE_DIR : File.expand_path(USER_DEFAULT_CACHE_DIR))
    @options[:translate_options] ||= {}

    assign_options(@options)
  end
  
  def merge!(options)
    @options.merge!(options)

    assign_options(options)
  end
  
  def debug?
    @debug || false
  end
  
  # compare two configurations
  def ==(other)
    @options == other.options
  end

  # return the range
  def range
    raise ArgumentError unless 2 == @range.size
    Range.new(time_to_date(@range.first), time_to_date(@range.last)) # inclusive
  end
  
  # set a range by a single Chronic expression or an array of 1 or 2 Chronic expressions
  def range=(args)
    args ||= []
    args = [args] unless args.is_a?(Array)
    
    @range_value = args
    
    raise ArgumentError.new("too many range items") if args.size > 2

    range = []
    args.each_with_index do |expr, i|
      raise RangeError if i > 1 # this should have been caught by ArgumentError before the loop
      
      chronic_options = { :context => :past, :guess => false }
      if self.now
        chronic_options.merge!(:now => Chronic.parse(self.now, :context => :past))
      end
      
      if span = Chronic.parse(expr, chronic_options)
        if span.width <= 24 * 3600 # on same date
          range << span.begin
        else
          raise RangeError, "range end '#{expr}' is not a single date" if i > 0
          range << span.begin
          range << span.end + (self.now ? 0 : -1)
        end
      else
        raise RangeError, "invalid expression '#{expr}'"
      end
    end
    
    range = [ Date.today ] if range.empty? # empty range means today
    range = range*2 if 1 == range.size     # single day has begin == end

    @range = range
  end
  
  def translate_options=(opts)
    @translate_options = {:recalculate_partial_content => false}.merge(opts)
  end

  def output_file(variables)
    Ralf::Interpolation.interpolate(@output_file, variables)
  end
  
  def output_file_format
    @output_file
  end
  
  def cache_dir(variables)
    Ralf::Interpolation.interpolate(@cache_dir, variables, [:bucket])
  end
  
  def cache_dir_format
    @cache_dir
  end
  
  def empty?
    @options.empty?
  end
  
  def valid?
    @errors = []
    unless (@aws_access_key_id || ENV['AWS_ACCESS_KEY_ID'])
      @errors << 'aws_access_key_id missing'
    end
      
    unless (@aws_secret_access_key || ENV['AWS_SECRET_ACCESS_KEY'])
      @errors << 'aws_secret_access_key missing'
    end
  end
  
  def validate!
    valid?
    unless @errors.empty?
      raise ConfigurationError.new(@errors.join(', '))
    end
  end
  
  def output_file_missing?
    !@output_file
  end
  
  private
  
  def time_to_date(time)
    Date.new(time.year, time.month, time.day)
  end
  
  def assign_options(new_options)
    options = new_options.dup

    # always re-assign range in case now has changed
    if options.has_key?(:now)
      self.now   = options.delete(:now)   
      self.range = options.delete(:range) || @range_value
    end
    options.each do |attr, val|
      begin
        self.send("#{attr.to_s}=", val)
      rescue NoMethodError => e
        puts "Warning: invalid configuration variable: #{method_name(e)}"
      end
    end
  end
  
  # Take NoMethodException string and extract the method name,
  # e.g. "undefined method `out_path=' for #<Ralf::Config:0x17931b8>"
  # should return 'out_path'
  def method_name(e)
    e.to_s.split('`')[1].split('=')[0]
  end
  
end