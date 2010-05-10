class Ralf

  class Interpolation
    class NotAllInterpolationsSatisfied < StandardError ; end
    class VariableMissing               < StandardError ; end

    def self.interpolate(string, date, bucket = nil)
      raise VariableMissing, ':bucket variable missing' unless bucket.nil? or string.match(/:bucket/)
      processor = Ralf::Interpolation.new(string, date, bucket)
      raise NotAllInterpolationsSatisfied, "Not all keys are interpolated: '#{string}'" if processor.result.match(/:/)
      processor.result
    end

    attr :result

    def initialize(string, date, bucket = nil)
      @bucket = bucket
      @date = date
      @result = string.dup
      Ralf::Interpolation.instance_methods(false).each do |tag|
        @result.gsub!(/:#{tag}/, self.send( tag )) unless self.send(tag).nil?
      end
    end
    
    def bucket
      @bucket
    end

    def week
      "%02d" % @date.cweek
    end

    def day
      "%02d" % @date.day
    end

    def month
      "%02d" % @date.month
    end

    def year
      "%04d" % @date.year
    end

  end

end