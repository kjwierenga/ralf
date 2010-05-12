class Ralf

  class Interpolation
    class NotAllInterpolationsSatisfied < StandardError ; end
    class VariableMissing               < StandardError ; end

    def self.interpolate(string, variables, required_variables = [])
      required_variables.each do |name|
        raise VariableMissing, ":#{name.to_s} variable missing" unless string.match(/:#{name.to_s}/)
      end
      processor = Ralf::Interpolation.new(string, variables)
      raise NotAllInterpolationsSatisfied, "Not all keys are interpolated: '#{string}'" if processor.result.match(/:/)
      processor.result
    end
    
    attr :result

    def initialize(string, variables)
      @variables = variables
      @result = string.dup
      (Ralf::Interpolation.public_instance_methods(false) - ['result']).each do |tag|
        @result.gsub!(/:#{tag}/, self.send( tag )) unless self.send(tag).nil?
      end
    end

    def bucket
      @variables[:bucket]
    end

    def week
      "%02d" % @variables[:date].cweek if @variables[:date]
    end

    def day
      "%02d" % @variables[:date].day if @variables[:date]
    end

    def month
      "%02d" % @variables[:date].month if @variables[:date]
    end

    def year
      "%04d" % @variables[:date].year if @variables[:date]
    end

  end

end