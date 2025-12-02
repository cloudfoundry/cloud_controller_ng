require 'spec_helper'

describe Vmstat::ProcFS do
  let(:procfs) do
    Class.new do
      extend Vmstat::ProcFS

      def self.procfs_path
        File.expand_path("../../procfs", __FILE__)
      end
    end
  end
  subject { procfs }

  context "#cpu" do
    subject { procfs.cpu }

    it { should be_a(Array)}
    it do 
      should == [
        Vmstat::Cpu.new(0, 311, 966, 0, 26788),
        Vmstat::Cpu.new(1, 351, 862, 0, 27263),
        Vmstat::Cpu.new(2, 324, 1092, 0, 26698),
        Vmstat::Cpu.new(30, 326, 838, 0, 27581)
      ]
    end
  end

  context "#memory" do
    subject { procfs.memory }
    
    it { should be_a(Vmstat::Memory) }
    if `getconf PAGESIZE`.chomp.to_i == 4096
      it do
        should == Vmstat::Memory.new(4096, 4906, 6508, 8405, 107017, 64599, 1104)
      end

      it "should have the right total" do
        (subject.wired_bytes + subject.active_bytes +
         subject.inactive_bytes + subject.free_bytes).should == 507344 * 1024
      end
    end
  end

  context "#boot_time" do
    subject { procfs.boot_time }

    it { should be_a(Time) }
    it { Timecop.freeze(Time.now) { should == Time.now - 355.63 } }
  end

  context "#network_interfaces" do
    subject { procfs.network_interfaces }

    it { should be_a(Array) }
    it do
      should == [
        Vmstat::NetworkInterface.new(:lo, 3224, 0, 0, 3224, 0,
                                     Vmstat::NetworkInterface::LOOPBACK_TYPE),
        Vmstat::NetworkInterface.new(:eth1, 0, 1, 2, 0, 3,
                                     Vmstat::NetworkInterface::ETHERNET_TYPE),
        Vmstat::NetworkInterface.new(:eth0, 33660, 0, 0, 36584, 0,
                                     Vmstat::NetworkInterface::ETHERNET_TYPE)
      ]
    end
  end

  context "#task" do
    subject { procfs.task }

    it { should be_a(Vmstat::Task) }
    if `getconf PAGESIZE`.chomp.to_i == 4096
      it { should == Vmstat::Task.new(4807, 515, 2000, 0) }
    end
  end
end
