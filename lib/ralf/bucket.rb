require 'ralf/log'
class Ralf

  class Bucket
    
    def initialize(bucket)
      raise ArgumentError.new("Bucket.s3 not assigned yet") if @@s3.nil?
      
      @bucket = bucket
      @logging_info = @bucket.logging_info
      if @bucket.name != @logging_info[:targetbucket]
        @targetbucket = @@s3.bucket(@logging_info[:targetbucket])
      else
        @targetbucket = @bucket
      end
    end

    def self.s3=(s3)
      @@s3 = s3
    end

    def self.each(names, with_logging = true)
      # find specified buckets
     if names
       names.map do |name|
         if s3_bucket = @@s3.bucket(name)
           bucket = Bucket.new(s3_bucket)
           yield bucket if !with_logging or bucket.logging_enabled?
         else
           puts("Warning: bucket '#{name}' not found.") if bucket.nil?
         end
       end
     else
       @@s3.buckets.each do |s3_bucket|
         bucket = Bucket.new(s3_bucket)
         yield bucket if !with_logging or bucket.logging_enabled?
       end
     end
    end
    
    def name
      @bucket.name
    end
    
    def logging_enabled?
      !!@logging_info[:enabled]
    end
    
    def targetbucket
      @logging_info[:targetbucket]
    end

    def targetprefix
      @logging_info[:targetprefix]
    end
    
    def each_log(date)
      search_string = "%s%s" % [@logging_info[:targetprefix], date]
      @targetbucket.keys(:prefix => search_string).each do |key|
        yield Log.new(key, @logging_info[:targetprefix])
      end
    end
  end

end