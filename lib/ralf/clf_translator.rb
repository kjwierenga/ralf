class Ralf::ClfTranslator

  AMAZON_LOG_FORMAT =      Regexp.new('([^ ]*) ([^ ]*) \[([^\]]*)\] ([^ ]*) ([^ ]*) ([^ ]*) ([^ ]*) ([^ ]*) "([^"]*)" ([^ ]*) ([^ ]*) ([^ ]*) ([^ ]*) ([^ ]*) ([^ ]*) "([^"]*)" "([^"]*)"')
  AMAZON_LOG_COPY_FORMAT = Regexp.new('([^ ]*) ([^ ]*) \[([^\]]*)\] ([^ ]*) ([^ ]*) ([^ ]*) (REST.COPY.OBJECT_GET) ([^ ]*) (-) ([^ ]*) (-) (-) ([^ ]*) (-) (-) (-) (-) (-)')

  attr :line
  attr_reader :owner, :bucket, :remote_ip, :request_id, :operation, :key, :request_uri, :http_status, :s3_error_code, :bytes_sent, :object_size, :total_time_in_ms, :turn_around_time_in_ms, :referrer, :user_agent, :request_version_id, :duration
  attr_reader :options

  # options:
  #   :recalculate_partial_content => false (default)
  #     If request is '206 Partial Content' estimate the actual bytes when apparent bandwidth has exceeded 2Mbit/sec.
  #     S3 caches content to edge servers with a burst which never reaches the client

  def initialize(line, options = {})
    @options = options
    @error = false
    @line = line
    @translate_successfull = translate
  end
  
  def timestamp
    Ralf::ClfTime.parse(@timestamp)
  end

  def to_s
    if @translate_successfull
      "%s - %s [%s] \"%s\" %s %s \"%s\" \"%s\" %d" % [remote_ip, requester, timestamp, request_uri, http_status, bytes_sent, referrer, user_agent, duration]
    else
      nil
    end
  end

private

  def requester
    @requester[0..9]
  end

  def translate
    if line =~ AMAZON_LOG_FORMAT
      @owner, @bucket, @timestamp, @remote_ip, @requester, @request_id, @operation, @key, @request_uri, @http_status, @s3_error_code, @bytes_sent, @object_size, @total_time_in_ms, @turn_around_time_in_ms, @referrer, @user_agent, @request_version_id = $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17, $18

      if options[:recalculate_partial_content] && 206 == http_status.to_i && ((bytes_sent.to_i*8)/total_time_in_ms.to_i > 2000)
        @bytes_sent = [ 128 * 1024 + 3 * total_time_in_ms.to_i, bytes_sent.to_i ].min # 128 K buffer + 3 bytes/msec = 3 kbytes/sec = 24 kbit/sec
      end
      @duration = (total_time_in_ms.to_i/1000.0).round

    elsif line =~ AMAZON_LOG_COPY_FORMAT
      @owner, @bucket, @timestamp, @remote_ip, @requester, @request_id, @operation, @key, @request_uri, @http_status, @s3_error_code, @bytes_sent, @object_size, @total_time_in_ms, @turn_around_time_in_ms, @referrer, @user_agent, @request_version_id = $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17, $18
      @operation == 'REST.COPY.OBJECT_GET'
      @user_agent = @operation
      @duration = 0
      @request_uri = "POST /#{@key} HTTP/1.1"

    else
      $stderr.puts "# ERROR: #{line}"
      false
    end
  end

end

# convert the format as specified in http://docs.aws.amazon.com/AmazonS3/latest/dev/LogFormat.html
# 
# 1 Bucket Owner  
#   The canonical user id of the owner of the source bucket.
# 2 Bucket  
#   The name of the bucket that the request was processed against. If the system receives a malformed request and cannot determine the bucket, the request will not appear in any server access log.
# 3 Time  
#   The time at which the request was received. The format, using strftime() terminology, is [%d/%b/%Y:%H:%M:%S %z]
# 4 Remote IP 
#   The apparent Internet address of the requester. Intermediate proxies and firewalls might obscure the actual address of the machine making the request.
# 5 Requester 
#   The canonical user id of the requester, or the string "Anonymous" for unauthenticated requests. This identifier is the same one used for access control purposes.
# 6 Request ID  
#   The request ID is a string generated by Amazon S3 to uniquely identify each request.
# 7 Operation 
#   Either SOAP.operation, REST.HTTP_method.resource_type or WEBSITE.HTTP_method.resource_type
# 8 Key 
#   The "key" part of the request, URL encoded, or "-" if the operation does not take a key parameter.
# 9 Request-URI 
#   The Request-URI part of the HTTP request message.
# 10 HTTP status 
#   The numeric HTTP status code of the response.
# 11 Error Code  
#   The Amazon S3 Error Code, or "-" if no error occurred.
# 12 Bytes Sent  
#   The number of response bytes sent, excluding HTTP protocol overhead, or "-" if zero.
# 13 Object Size 
#   The total size of the object in question.
# 14 Total Time  
#   The number of milliseconds the request was in flight from the server's perspective. This value is measured from the time your request is received to the time that the last byte of the response is sent. Measurements made from the client's perspective might be longer due to network latency.
# 15 Turn-Around Time  
#   The number of milliseconds that Amazon S3 spent processing your request. This value is measured from the time the last byte of your request was received until the time the first byte of the response was sent.
# 16 Referrer  
#   The value of the HTTP Referrer header, if present. HTTP user-agents (e.g. browsers) typically set this header to the URL of the linking or embedding page when making a request.
# 17 User-Agent  
#   The value of the HTTP User-Agent header.
# 18 Version Id
#   The version ID in the request, or "-" if the operation does not take a versionId parameter.