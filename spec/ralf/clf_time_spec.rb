require 'spec_helper'
require 'ralf/clf_time'
require 'time'

describe Ralf::ClfTime do

  describe ".parse" do
    it "converts '04/Jun/2012:16:34:26 +0000' to a proper timestamp" do
      time = Time.mktime(2012, 6, 4, 16, 34, 26, '+0000').utc
      Ralf::ClfTime.parse('04/Jun/2012:16:34:26 +0000').should eql(time)
    end
  end

end