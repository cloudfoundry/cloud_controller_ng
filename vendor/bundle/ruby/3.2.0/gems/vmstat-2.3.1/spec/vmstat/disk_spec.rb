require 'spec_helper'

describe Vmstat::Disk do
  context "sample" do
    let(:disk) { described_class.new :hfs, "/dev/disk0", "/mnt/test",
                                     4096, 100, 200, 600 }
    subject { disk }

    its(:type) { should == :hfs }
    its(:origin) { should == "/dev/disk0" }
    its(:mount) { should == "/mnt/test" }

    its(:block_size) { should == 4096 }
    its(:free_blocks) { should == 100 }
    its(:available_blocks) { should == 200 }
    its(:total_blocks) { should == 600 }

    its(:free_bytes) { should == 409600 }
    its(:available_bytes) { should == 819200 }
    its(:used_bytes) { should == 2048000 }
    its(:total_bytes) { should == 2457600 }
  end

  context "Vmstat#disk" do
    let(:disk) { Vmstat.disk("/") }
    subject { disk }

    it "should be a vmstat disk object" do
      should be_a(described_class)
    end

    context "methods" do
      it { should respond_to(:type) }
      it { should respond_to(:origin) }
      it { should respond_to(:mount) }
      it { should respond_to(:free_bytes) }
      it { should respond_to(:available_bytes) }
      it { should respond_to(:used_bytes) }
      it { should respond_to(:total_bytes) }
    end
    
    context "content" do
      its(:type) { should be_a(Symbol) }
      its(:origin) { should be_a(String) }
      its(:mount) { should be_a(String) }
      its(:free_bytes) { should be_a_kind_of(Numeric) }
      its(:available_bytes) { should be_a_kind_of(Numeric) }
      its(:used_bytes) { should be_a_kind_of(Numeric) }
      its(:total_bytes) { should be_a_kind_of(Numeric) }
    end
  end
end
