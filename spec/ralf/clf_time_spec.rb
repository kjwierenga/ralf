require 'spec_helper'
require 'ralf/clf_time'
require 'time'

describe Ralf::ClfTime do

  describe ".parse" do
    it "converts '04/Jun/2012:16:34:26 +0000' to a proper timestamp" do
      Ralf::ClfTime.parse('04/Jun/2012:16:34:26 +0000').to_s.should eql("2012-06-04T16:34:26+00:00")
    end
    it "converts '04/Jun/2012:18:34:26 +0200' to a proper timestamp" do
      Ralf::ClfTime.parse('04/Jun/2012:18:34:26 +0200').to_s.should eql("2012-06-04T18:34:26+02:00")
    end
    it "converts '10/Feb/2010:07:17:02 +0000' to a proper timestamp" do
      Ralf::ClfTime.parse('10/Feb/2010:07:17:02 +0000').to_s.should eql('2010-02-10T07:17:02+00:00')
    end
  end

end