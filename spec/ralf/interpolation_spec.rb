require File.dirname(__FILE__) + '/../spec_helper'

require 'ralf/interpolation'

describe Ralf::Interpolation do
  before(:all) do
    @bucket = 'bucket.mybuckets.org'
    @date = Date.strptime('2010-02-09')
  end

  [
    [':year',   '2010'],
    [':month',  '02'],
    [':day',    '09'],
    [':week',   '06']
  ].each do |match, result, bucket|
    it "should replace '#{match}' with '#{result}'" do
      Ralf::Interpolation.interpolate(match, :date => @date).should  eql(result)
    end
  end

  it "should raise an error when not all symbols could be interpolated" do
    lambda {
      Ralf::Interpolation.interpolate(':unknown', :date => @date)
    }.should raise_error(Ralf::Interpolation::NotAllInterpolationsSatisfied)
  end
  
  it "should interpolate :bucket" do
    Ralf::Interpolation.interpolate(':year/:month/:day/:bucket.log',
      :date => @date, :bucket => @bucket).should eql('2010/02/09/bucket.mybuckets.org.log')
  end

  it "should require :bucket interpolation if bucket specified" do
    lambda {
      Ralf::Interpolation.interpolate(':year/:month/:day.log', {:date => @date, :bucket => @bucket}, [:bucket])
    }.should raise_error(Ralf::Interpolation::VariableMissing, ':bucket variable missing')
  end
  
  it "should raise an error when :bucket can not be interpolated" do
    lambda {
      Ralf::Interpolation.interpolate(':bucket', :date => @date)
    }.should raise_error(Ralf::Interpolation::NotAllInterpolationsSatisfied)
  end

end
