class Ralf::Config
  
  class ConfigurationError < StandardError ; end
  class RangeError         < StandardError ; end

  attr_accessor \
    :aws_access_key_id,
    :aws_secret_access_key,
    :buckets,
    :range,
    :now,
    :output_file,
    :cache_dir
    
  attr_writer :debug, :list # booleans have ? readers, e.g. debug?
    
  attr_reader :errors
  
  protected
  
  attr_accessor :options
  
  public

  def self.load_file(filepath)
    self.new(YAML.load_file(filepath))
  end

  def initialize(options = {})
    @options = options
    @options.each { |attr, val| self.send("#{attr.to_s}=", val) }
  end
  
  def merge!(options)
    @options.merge!(options)
    options.each { |attr, val| self.send("#{attr.to_s}=", val) }
  end
  
  def cache_dir
    self.cache_dir ||= File.expand_path("~/.ralf_cache/:bucket")
  end
  
  def range
    self.rang || 'today'
  end
  
  def now
    self.now || 'today'
  end
  
  def debug?
    @debug || false
  end
  
  def list?
    @list || false
  end
  
  def ==(other)
    @options == other.options
  end
  
  def range
    raise ArgumentError unless 2 == @range.size
    Range.new(time_to_date(@range.first), time_to_date(@range.last)) # inclusive
  end
  
  def range=(args, now = nil)
    args ||= []
    args = [args] unless args.is_a?(Array)

    range = []
    args.each_with_index do |expr, i|
      raise RangeError, "unused extra argument '#{expr}'" if i > 1
      
      chronic_options = { :context => :past, :guess => false }
      if now
        chronic_options.merge!(:now => Chronic.parse(now, :context => :past))
      end
      
      if span = Chronic.parse(expr, chronic_options)
        if span.width <= 24 * 3600 # on same date
          range << span.begin
        else
          raise RangeError, "range end '#{expr}' is not a single date" if i > 0
          range << span.begin
          range << span.end + (now ? 0 : -1)
        end
      else
        raise RangeError, "invalid expression '#{expr}'"
      end
    end
    
    range = [ Date.today ] if range.empty? # empty range means today
    range = range*2 if 1 == range.size     # single day has begin == end
    
    @range = range
  end
  
  def output_file(date, bucket = nil)
    Ralf::Interpolation.interpolate(@output_file, date, bucket)
  end
  
  def cache_dir(date, bucket)
    Ralf::Interpolation.interpolate(@cache_dir, date, bucket)
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
    
    unless (@list || @output_file)
      @errors << '--list or --output-file required'
    end
  end
  
  def validate!
    valid?
    unless @errors.empty?
      raise ConfigurationError.new(@errors.join(', '))
    end
  end
  
  private
  
  def time_to_date(time)
    Date.new(time.year, time.month, time.day)
  end
  
end