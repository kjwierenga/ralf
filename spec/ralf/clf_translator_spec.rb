require 'spec_helper'

require 'ralf'
require 'ralf/bucket'

describe Ralf::ClfTranslator do

  it "should return nil when it's an invalid line" do
    $stderr = StringIO.new
    translated_object = Ralf::ClfTranslator.new('invalid_line')
    translated_object.to_s.should be_nil
    $stderr.string.should eql("# ERROR: invalid_line\n")
  end

  it "should translate a amazon logline to a Apache CombinedLogFile" do
    aws_line = '2cf7e6b06335c0689c6d29163df5bb001c96870cd78609e3845f1ed76a632621 media.kerkdienstgemist.nl [03/Nov/2010:15:57:29 +0000] 84.82.12.240 2cf7e6b06335c0689c6d29163df5bb001c96870cd78609e3845f1ed76a632621 AE5C72112DFB80DE REST.GET.OBJECT 10122150/2010-10-31-0930.mp3 "GET /10122150/2010-10-31-0930.mp3?Signature=5n2%2B8hrDvgSbP6OJRP1vVav42uU%3D&Expires=1288807041&AWSAccessKeyId=AKIAI3XHXJPFSJW2UQAQ HTTP/1.0" 200 - 4215272 18708200 5165 47 "-" "WinampMPEG/5.56, Ultravox/2.1" -'
    clf_line = '84.82.12.240 - 2cf7e6b063 [03/Nov/2010:15:57:29 +0000] "GET /10122150/2010-10-31-0930.mp3?Signature=5n2%2B8hrDvgSbP6OJRP1vVav42uU%3D&Expires=1288807041&AWSAccessKeyId=AKIAI3XHXJPFSJW2UQAQ HTTP/1.0" 200 4215272 "-" "WinampMPEG/5.56, Ultravox/2.1" 5'
    translated_object = Ralf::ClfTranslator.new(aws_line)
    translated_object.to_s.should eql(clf_line)
  end

  it "should mark invalid lines with '# ERROR: '" do
    $stderr = StringIO.new
    invalid_line = "this is an invalid log line"
    Ralf::ClfTranslator.new(invalid_line)
    $stderr.string.should eql("# ERROR: #{invalid_line}\n")
  end
  
  describe "#option{:fix_partial_content}" do
    describe "set to false (default)" do
      it "should add rounded total_time in seconds" do
        $stderr = StringIO.new
        input_line = '2010-10-02-19-15-45-6879098C3140BE9D:2cf7e6b06335c0689c6d29163df5bb001c96870cd78609e3845f1ed76a632621 media.kerkdienstgemist.nl [02/Oct/2010:18:29:16 +0000] 82.168.113.55 2cf7e6b06335c0689c6d29163df5bb001c96870cd78609e3845f1ed76a632621 4F911681022807C6 REST.GET.OBJECT 10028050/2010-09-26-1830.mp3 "GET /10028050/2010-09-26-1830.mp3?Signature=E3ehd6nkXjNg7vr%2F4b3LtxCWads%3D&Expires=1286051333&AWSAccessKeyId=AKIAI3XHXJPFSJW2UQAQ HTTP/1.1" 206 - 4194304 17537676 1600 12 "-" "VLC media player - version 1.0.5 Goldeneye - (c) 1996-2010 the VideoLAN team" -'
        Ralf::ClfTranslator.new(input_line).to_s.should eql("82.168.113.55 - 2cf7e6b063 [02/Oct/2010:18:29:16 +0000] \"GET /10028050/2010-09-26-1830.mp3?Signature=E3ehd6nkXjNg7vr%2F4b3LtxCWads%3D&Expires=1286051333&AWSAccessKeyId=AKIAI3XHXJPFSJW2UQAQ HTTP/1.1\" 206 4194304 \"-\" \"VLC media player - version 1.0.5 Goldeneye - (c) 1996-2010 the VideoLAN team\" 2")
        $stderr.string.should be_empty
      end
    end
    describe "set to true" do
      it "should add rounded total_time in seconds" do
        $stderr = StringIO.new
        input_line = '2010-10-02-19-15-45-6879098C3140BE9D:2cf7e6b06335c0689c6d29163df5bb001c96870cd78609e3845f1ed76a632621 media.kerkdienstgemist.nl [02/Oct/2010:18:29:16 +0000] 82.168.113.55 2cf7e6b06335c0689c6d29163df5bb001c96870cd78609e3845f1ed76a632621 4F911681022807C6 REST.GET.OBJECT 10028050/2010-09-26-1830.mp3 "GET /10028050/2010-09-26-1830.mp3?Signature=E3ehd6nkXjNg7vr%2F4b3LtxCWads%3D&Expires=1286051333&AWSAccessKeyId=AKIAI3XHXJPFSJW2UQAQ HTTP/1.1" 206 - 4194304 17537676 1600 12 "-" "VLC media player - version 1.0.5 Goldeneye - (c) 1996-2010 the VideoLAN team" -'
        Ralf::ClfTranslator.new(input_line, :fix_partial_content => true).to_s.should eql("82.168.113.55 - 2cf7e6b063 [02/Oct/2010:18:29:16 +0000] \"GET /10028050/2010-09-26-1830.mp3?Signature=E3ehd6nkXjNg7vr%2F4b3LtxCWads%3D&Expires=1286051333&AWSAccessKeyId=AKIAI3XHXJPFSJW2UQAQ HTTP/1.1\" 206 135872 \"-\" \"VLC media player - version 1.0.5 Goldeneye - (c) 1996-2010 the VideoLAN team\" 2")
        $stderr.string.should be_empty
      end
    end
  end

 [
    ['2cf7e6b06335c0689c6d29163df5bb001c96870cd78609e3845f1ed76a632621 assets.staging.kerkdienstgemist.nl [10/Feb/2010:07:17:01 +0000] 10.32.219.38 3272ee65a908a7677109fedda345db8d9554ba26398b2ca10581de88777e2b61 784FD457838EFF42 REST.GET.ACL - "GET /?acl HTTP/1.1" 200 - 1384 - 399 - "-" "Jakarta Commons-HttpClient/3.0" -',
     '10.32.219.38 - 3272ee65a9 [10/Feb/2010:07:17:01 +0000] "GET /?acl HTTP/1.1" 200 1384 "-" "Jakarta Commons-HttpClient/3.0" 0'],
    ['2cf7e6b06335c0689c6d29163df5bb001c96870cd78609e3845f1ed76a632621 assets.staging.kerkdienstgemist.nl [10/Feb/2010:07:17:02 +0000] 10.32.219.38 3272ee65a908a7677109fedda345db8d9554ba26398b2ca10581de88777e2b61 6E239BC5A4AC757C SOAP.PUT.OBJECT logs/2010-02-10-07-17-02-F6EFD00DAB9A08B6 "POST /soap/ HTTP/1.1" 200 - 797 686 63 31 "-" "Axis/1.3" -',
     '10.32.219.38 - 3272ee65a9 [10/Feb/2010:07:17:02 +0000] "POST /soap/ HTTP/1.1" 200 797 "-" "Axis/1.3" 0'],
    ['2cf7e6b06335c0689c6d29163df5bb001c96870cd78609e3845f1ed76a632621 assets.staging.kerkdienstgemist.nl [10/Feb/2010:07:24:40 +0000] 10.217.37.15 - 0B76C90B3634290B REST.GET.ACL - "GET /?acl HTTP/1.1" 307 TemporaryRedirect 488 - 7 - "-" "Jakarta Commons-HttpClient/3.0" -',
     '10.217.37.15 - - [10/Feb/2010:07:24:40 +0000] "GET /?acl HTTP/1.1" 307 488 "-" "Jakarta Commons-HttpClient/3.0" 0'],
    ['2cf7e6b06335c0689c6d29163df5bb001c96870cd78609e3845f1ed76a632621 media.staging.kerkdienstgemist.nl [17/Sep/2010:13:38:36 +0000] 85.113.244.146 2cf7e6b06335c0689c6d29163df5bb001c96870cd78609e3845f1ed76a632621 71F7D2AAA93B0A05 REST.COPY.OBJECT_GET 10010150/2010-08-29-0930.mp3 - 200 - - 13538337 - - - - -',
     '85.113.244.146 - 2cf7e6b063 [17/Sep/2010:13:38:36 +0000] "POST /10010150/2010-08-29-0930.mp3 HTTP/1.1" 200 - "-" "REST.COPY.OBJECT_GET" 0'],
    ['2cf7e6b06335c0689c6d29163df5bb001c96870cd78609e3845f1ed76a632621 media.staging.kerkdienstgemist.nl [17/Sep/2010:13:38:37 +0000] 85.113.244.146 2cf7e6b06335c0689c6d29163df5bb001c96870cd78609e3845f1ed76a632621 7CC5E3D09AE78CAE REST.COPY.OBJECT_GET 10010150/2010-09-05-1000.mp3 - 200 - - 9860402 - - - - -',
     '85.113.244.146 - 2cf7e6b063 [17/Sep/2010:13:38:37 +0000] "POST /10010150/2010-09-05-1000.mp3 HTTP/1.1" 200 - "-" "REST.COPY.OBJECT_GET" 0'],
  ].each do |aws_line,clf_line|
    it "converts #{aws_line} into #{clf_line}" do
      Ralf::ClfTranslator.new(aws_line).to_s.should eql(clf_line)
    end
  end
end
