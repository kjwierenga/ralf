require 'fileutils'

class Ralf::BucketProcessor

  attr_reader :config
  attr_reader :bucket
  attr_reader :open_files

  def initialize(s3_bucket, ralf)
    @open_files = {}
    @bucket = s3_bucket
    @config = ralf.config
    @keys = []
  end

  def process
    file_names_to_process = process_keys_for_range.flatten
    all_loglines = merge(file_names_to_process)
    write_to_day_files(all_loglines)
    combine_day_files
  end

  def combine_day_files
    covered_months.collect do |date|
      base_dir =        Ralf::Interpolation.interpolate([config[:output_dir],'[0-9][0-9].log'].join('/'), {:bucket => bucket.name, :date => date}, [:bucket])
      output_filename = Ralf::Interpolation.interpolate(config[:month_file], {:bucket => bucket.name, :date => date}, [:bucket])
      out = File.open(output_filename, "w")
      Dir[base_dir].each do |f|
        File.open(f).read.each do |line|
          out << line
        end
      end
      out.close
    end
  end

  def process_keys_for_range
    date_range.collect { |date| process_keys_for_date(date)}
  end

  def process_keys_for_date(date)
    debug("\nProcess keys for date #{date}")
    keys = bucket.keys('prefix' => prefix(date))
    keys.collect { |key| download_key(key) }
  end

  def download_key(key)
    file_name = File.join(cache_dir, key.name.gsub(config[:log_prefix], ''))
    unless File.exist?(file_name)
      print "%s: Downloading: %s\r" % [DateTime.now, file_name] if config[:debug]
      $stdout.flush
      File.open(file_name, 'w') { |f| f.write(key.data) }
    end
    file_name
  end

  def merge(file_names)
    debug("Merging %05d files" % file_names.size)
    lines = []
    file_names.each_with_index do |file_name, idx|
      print "%s: %05d Reading: %s \r" % [DateTime.now, idx, file_name] if config[:debug]
      $stdout.flush
      File.open(file_name) do |in_file|
        while (line = in_file.gets)
          translated = Ralf::ClfTranslator.new(line, config)
          lines << {:timestamp => translated.timestamp, :string => translated.to_s}
        end
      end
    end
    debug("\nSorting...")
    lines.sort! { |a,b| a[:timestamp] <=> b[:timestamp] }
  end

  def write_to_day_files(all_loglines)
    ensure_output_directories
    open_file_descriptors
    debug("Write to Dayfiles")

    all_loglines.each do |line|
      open_files[key_for_date(line[:timestamp])].puts(line[:string]) if open_files[key_for_date(line[:timestamp])]
    end

  ensure
    close_file_descriptors
  end

  def open_file_descriptors
    date_range_with_ignored_days.each do |date|
      output_filename = Ralf::Interpolation.interpolate(config[:day_file], {:bucket => bucket.name, :date => date}, [:bucket])
      @open_files[key_for_date(date)] = File.open(output_filename, 'w')
    end
    debug("Opened outputs")
  end

  def close_file_descriptors
    open_files.each {|k,v| v.close }
    debug("Closed outputs")
  end

  def ensure_output_directories
    date_range_with_ignored_days.each do |date|
      base_dir = Ralf::Interpolation.interpolate(config[:output_dir], {:bucket => bucket.name, :date => date}, [:bucket])
      unless File.exist?(base_dir)
        FileUtils.mkdir_p(base_dir)
      end
    end
  end

  def cache_dir
    @cache_dir ||= begin
      interpolated_cache_dir = Ralf::Interpolation.interpolate(config[:cache_dir], {:bucket => bucket.name}, [:bucket])
      raise Ralf::InvalidConfig.new("Required options: 'Cache dir does not exixst'") unless File.exist?(interpolated_cache_dir)
      interpolated_cache_dir
    end
  end

  def date_range_with_ignored_days
    date_range[config[:days_to_ignore], config[:days_to_look_back]]
  end

  def date_range
    (start_day..Date.today).to_a
  end

  def covered_months
    month_start = Date.new(start_day.year, start_day.month)
    (month_start..Date.today).select {|d| d.day == 1}
  end

private

  def key_for_date(date)
    "%d%02d%02d" % [date.year, date.month, date.day]
  end

  def start_day
    Date.today-(config[:days_to_look_back]-1)
  end

  def prefix(date)
    "%s%s" % [config[:log_prefix], date]
  end

  def debug(str)
    puts "%s: %s" % [DateTime.now, str] if config[:debug]
  end

end
