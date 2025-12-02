require 'spec_helper'

describe Vmstat::Memory do
  context "sample" do
    let(:disk) { described_class.new 4096, 775581, 196146, 437495, 685599,
                                     1560532, 0 }
    subject { disk }

    its(:pagesize) { should == 4096 }

    its(:wired) { should == 775581 }
    its(:active) { should == 196146 }
    its(:inactive) { should == 437495 }
    its(:free) { should == 685599 }

    its(:wired_bytes) { should == 3176779776 }
    its(:active_bytes) { should == 803414016 }
    its(:inactive_bytes) { should == 1791979520 }
    its(:free_bytes) { should == 2808213504 }
    its(:total_bytes) { should == 8580386816 }

    its(:pageins) { should == 1560532 }
    its(:pageouts) { should == 0 }
  end

  context "Vmstat#memory" do
    let(:memory) { Vmstat.memory }
    subject { memory }

    it "should be a vmstat memory object" do
      should be_a(described_class)
    end

    context "methods" do
      it { should respond_to(:pagesize) }
      it { should respond_to(:wired) }
      it { should respond_to(:active) }
      it { should respond_to(:inactive) }
      it { should respond_to(:free) }
      it { should respond_to(:pageins) }
      it { should respond_to(:pageouts) }

      it { should respond_to(:wired_bytes) }
      it { should respond_to(:active_bytes) }
      it { should respond_to(:inactive_bytes) }
      it { should respond_to(:free_bytes) }
      it { should respond_to(:total_bytes)}
    end

    context "content" do
      its(:pagesize) { should be_a_kind_of(Numeric) }
      its(:wired) { should be_a_kind_of(Numeric) }
      its(:active) { should be_a_kind_of(Numeric) }
      its(:inactive) { should be_a_kind_of(Numeric) }
      its(:free) { should be_a_kind_of(Numeric) }
      its(:pageins) { should be_a_kind_of(Numeric) }
      its(:pageouts) { should be_a_kind_of(Numeric) }

      its(:wired_bytes) { should be_a_kind_of(Numeric) }
      its(:active_bytes) { should be_a_kind_of(Numeric) }
      its(:inactive_bytes) { should be_a_kind_of(Numeric) }
      its(:free_bytes) { should be_a_kind_of(Numeric) }
      its(:total_bytes) { should be_a_kind_of(Numeric) }
    end
  end
end
