require 'spec_helper'

describe Vmstat::NetworkInterface do
  context "Vmstat#network" do
    let(:network) { Vmstat.network_interfaces }

    it "should return the enthernet and loopback network data as an array" do
      network.should be_a(Array)
    end

    context "loopback device" do
      let(:loopback) { network.find { |interface| interface.loopback? } }
      subject { loopback }

      it "should be a vmstat network interface object" do
        should be_a(described_class)
      end

      context "methods" do
        it { should respond_to(:in_bytes) }
        it { should respond_to(:out_bytes) }
        it { should respond_to(:in_errors) }
        it { should respond_to(:out_errors) }
        it { should respond_to(:in_drops) }
        it { should respond_to(:type) }
      end

      context "content" do
        its(:in_bytes) { should be_a_kind_of(Numeric) }
        its(:out_bytes) { should be_a_kind_of(Numeric) }
        its(:in_errors) { should be_a_kind_of(Numeric) }
        its(:out_errors) { should be_a_kind_of(Numeric) }
        its(:in_drops) { should be_a_kind_of(Numeric) }
        its(:type) { should be_a_kind_of(Numeric) }
      end
    end
  end
end
