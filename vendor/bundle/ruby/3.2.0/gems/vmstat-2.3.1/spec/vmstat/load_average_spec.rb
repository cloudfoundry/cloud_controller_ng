require 'spec_helper'

describe Vmstat::LoadAverage do
  context "Vmstat#load_average" do
    subject { Vmstat.load_average }

    it "should be an vmstat load average object" do
      should be_a(described_class)
    end

    context "methods" do
      it { should respond_to(:one_minute) }
      it { should respond_to(:five_minutes) }
      it { should respond_to(:fifteen_minutes) }
    end

    context "content" do
      its(:one_minute) { should be_a(Float) }
      its(:five_minutes) { should be_a(Float) }
      its(:fifteen_minutes) { should be_a(Float) }
    end
  end
end
