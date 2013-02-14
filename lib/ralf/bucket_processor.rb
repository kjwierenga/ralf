
class Ralf::BucketProcessor

  attr_reader :config
  attr_reader :bucket
  attr_reader :open_files

  def initialize(s3_bucket, ralf)
    @bucket = s3_bucket
    @config = ralf.config
    @keys = []
  end

  def process
    file_names_to_process = process_keys_for_range.flatten
    all_loglines = merge(file_names_to_process)
    write_to_combined(all_loglines)
  end

  def process_keys_for_range
    (start_day..Date.today).to_a.each { |date| process_keys_for_date(date)}
  end

  def process_keys_for_date(date)
    keys = bucket.keys('prefix' => prefix(date))
    keys.collect { |key| download_key(key) }
  end

  def download_key(key)
    file_name = File.join(config[:cache_dir], key.name.gsub(config[:log_prefix], ''))
    unless File.exist?(file_name)
      File.open(file_name, 'w') { |f| f.write(key.data) }
    end
    file_name
  end

  def merge(file_names)
    file_names.collect do |file_name|
      lines = []
      File.open(file_name) do |in_file|
        while (line = in_file.gets)
          lines << Ralf::ClfTranslator.new(line, config)
        end
      end
      lines
    end.flatten.sort! { |a,b| a.timestamp <=> b.timestamp }
  end

  def write_to_combined(all_loglines)
    range = extract_range_from_collection(all_loglines)
    range.shift(config[:days_to_ignore]) # remove N items from range
    ensure_output_directories(range)
    open_file_descriptors(range)
    
    all_loglines.each do |line|
      open_files[line.timestamp.year][line.timestamp.month][line.timestamp.day].puts line if range.include? Date.parse(line.timestamp.strftime("%Y/%m/%d"))
    end
  ensure
    close_file_descriptors
  end

  def open_file_descriptors(range)
    @open_files = {}
    range.each do |date|
      output_filename = Ralf::Interpolation.interpolate(config[:output_dir], {:bucket => bucket.name, :date => date}, [:bucket])
      @open_files[date.year] ||= {}
      @open_files[date.year][date.month] ||= {}
      @open_files[date.year][date.month][date.day] = File.open(output_filename)
    end
  end

  def close_file_descriptors
    open_files.each do |year, year_values|
      year_values.each do |month, month_values|
        month_values.each do |day, day_values|
          day_values.close
        end
      end
    end
  end

  def ensure_output_directories(range)
    range.each do |date|
      output_filename = Ralf::Interpolation.interpolate(config[:output_dir], {:bucket => bucket.name, :date => date}, [:bucket])
      base_dir = File.dirname(output_filename)
      unless File.exist?(base_dir)
        FileUtils.mkdir_p(base_dir)
      end
    end
  end

private

  def extract_range(all_loglines)
    (Date.parse(all_loglines.first.timestamp.strftime("%Y/%m/%d"))..Date.parse(all_loglines.last.timestamp.strftime("%Y/%m/%d"))).to_a
  end

  def start_day
    Date.today-(config[:days_to_look_back]-1)
  end

  def prefix(date)
    "%s%s" % [config[:log_prefix], date]
  end

end
