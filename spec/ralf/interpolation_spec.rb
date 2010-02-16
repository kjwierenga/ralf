require File.dirname(__FILE__) + '/../spec_helper'

require 'ralf/interpolation'

describe Ralf::Interpolation do
  before(:all) do
    @date = Date.strptime('2010-02-10')
  end

  [
    [':year', '2010'],
    [':month',  '02'],
    [':day',    '10'],
    [':week',   '06']
  ].each do |match, result|
    it "should replace '#{match}' with '#{result}'" do
      Ralf::Interpolation.interpolate(@date, match).should  eql(result)
    end
  end

  it "should raise an error when not all symbols could be interpolated" do
    lambda {
      Ralf::Interpolation.interpolate(@date, ':unknown')
    }.should  raise_error(Ralf::Interpolation::NotAllInterpolationsSatisfied)
  end

end
