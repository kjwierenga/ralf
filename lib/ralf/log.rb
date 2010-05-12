class Ralf
  class Log
    def initialize(key, targetprefix)
      @key          = key
      @targetprefix = targetprefix
    end
  
    def name
      @key.name.gsub(@targetprefix, '')
    end
  
    def save_to_dir(dir, use_cache = true)
      file = File.join(dir, name)
      File.open(file, 'w') { |f| f.write(@key.data) } unless use_cache and File.exist?(file)
      file # return saved filename
    end
  end
end