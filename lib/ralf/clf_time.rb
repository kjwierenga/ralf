require 'time'

class Ralf::ClfTime

  def self.parse(apache_time)
    # apache_time =~ /(\d+)\/(\S+)\/(\d+):(\d+):(\d+):(\d+) (\S+)/
    # # d/m/y:h:m:s tz
    # # Time.local( $6, $5, $4, $1, $2, $3, 0, 0, 0, $7).utc
    # Time.mktime($3, $2, $1 , $4, $5, $6, $7).utc
    DateTime.strptime( apache_time, "%d/%b/%Y:%H:%M:%S %Z")
  end

end
