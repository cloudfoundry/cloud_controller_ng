require 'spec_helper'

describe Vmstat::Cpu do
  context "Vmstat#cpu" do
    let(:cpu) { Vmstat.cpu }

    it "should return an array of ethernet information" do
      cpu.should be_a(Array)
    end

    context "first cpu" do
      let(:first_cpu) { cpu.first }
      subject { first_cpu }

      it "should return a vmstat cpu object" do
        should be_a(described_class)
      end

      context "methods" do
        it { should respond_to(:user) }
        it { should respond_to(:system) }
        it { should respond_to(:nice) }
        it { should respond_to(:idle) }
      end

      context "content" do
        its(:user) { should be_a_kind_of(Numeric) }
        its(:system) { should be_a_kind_of(Numeric) }
        its(:nice) { should be_a_kind_of(Numeric) }
        its(:idle) { should be_a_kind_of(Numeric) }
      end
    end
  end
end
