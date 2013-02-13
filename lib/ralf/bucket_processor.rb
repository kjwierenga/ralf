
# √ sync the logfiles form the last N days onto the local filesystem
# √ load every logfile in memory and merge it in a hashtable
#   remove ignore lines
# √ sort it by timestamp
# save and optionally split it in a directory (ex. :year/:month/:day) as given in the options
# merge the last N days into combined ordered logs

class Ralf::BucketProcessor

  attr_reader :config
  attr_reader :bucket

  def initialize(s3_bucket, ralf)
    @bucket = s3_bucket
    @config = ralf.config
    @keys = []
  end

  def process
    merge(collected_files.flatten)
  end

  def collected_files
    ((Date.today-config[:range_size])..Date.today).to_a.each { |date| process_keys_for_date(date)}
  end

  def process_keys_for_date(date)
    keys = bucket.keys('prefix' => prefix(date))
    keys.collect { |key| download(key) }
  end

  def download(key)
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

private

  def prefix(date)
    "%s%s" % [config[:log_prefix], date]
  end

end
