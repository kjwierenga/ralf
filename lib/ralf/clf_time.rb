require 'time'

class Ralf::ClfTime

  def self.parse(apache_time)
    apache_time =~ /(\d+)\/(\S+)\/(\d+):(\d+):(\d+):(\d+) (\S+)/
    Time.mktime($3, $2, $1 , $4, $5, $6, $7).utc
  end

end
