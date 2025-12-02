require 'spec_helper'

describe Vmstat do
  context "#boot_time" do
    let(:boot_time) { Vmstat.boot_time }

    it "should be an array" do
      boot_time.should be_a(Time)
    end

    it "has to be a time before now" do
      boot_time.should < Time.now
    end
  end
  
  context "Vmstat#filter_devices" do
    unless travis? # no external ethernet devices on travis ci
      it "should filter ethernet devices" do
        Vmstat.ethernet_devices.size.should >= 1
      end
    end

    it "should filter loopback devices" do
      Vmstat.loopback_devices.size.should >= 1
    end
  end

  context "performance" do
    percent = RUBY_VERSION.to_i == 2 ? 26 : 10
    
    shared_examples "a not memory leaking method" do |method_name, *args|
      it "should not grow the memory in method #{method_name} " +
         "more than #{percent}% " do
        mem_before = Vmstat.task.resident_size
        10000.times { Vmstat.send(method_name, *args) }
        mem_after = Vmstat.task.resident_size
        mem_after.should < (mem_before * (1 + percent / 100.0))
      end
    end

    it_should_behave_like "a not memory leaking method", :network_interfaces
    it_should_behave_like "a not memory leaking method", :cpu
    it_should_behave_like "a not memory leaking method", :memory
    it_should_behave_like "a not memory leaking method", :disk, "/"
    it_should_behave_like "a not memory leaking method", :boot_time
    it_should_behave_like "a not memory leaking method", :load_average
  end if ENV['PERF'] == "1"
end
