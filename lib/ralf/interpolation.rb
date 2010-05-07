class Ralf

  class Interpolation
    class NotAllInterpolationsSatisfied < StandardError ; end

    def self.interpolate(date, string)
      processor = Ralf::Interpolation.new(date, string)
      raise NotAllInterpolationsSatisfied, "Not all keys are interpolated: '#{string}'" if processor.result.match(/:/)
      processor.result
    end

    attr :result

    def initialize(date, string)
      @date = date
      @result = string.dup
      Ralf::Interpolation.instance_methods(false).each do |tag|
        @result.gsub!(/:#{tag}/, self.send( tag ))
      end
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