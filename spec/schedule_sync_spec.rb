# Copyright (c) 2009-2012 VMware, Inc.

require File.expand_path("../spec_helper", __FILE__)
require "eventmachine"
require "eventmachine/schedule_sync"

describe "EventMachine#schdule_sync" do

  def with_em_and_thread(&blk)
    Thread.abort_on_exception = true
    EM.run do
      EM.reactor_thread?.should == true
      Thread.new do
        EM.reactor_thread?.should == false
        blk.call
        EM.reactor_thread?.should == false
      end
      EM.reactor_thread?.should == true
    end
  end

  it "should run a block on the reactor thread and return the result" do
    with_em_and_thread do
      result = EM.schedule_sync do
        EM.reactor_thread?.should == true
        "sync return from the reactor thread"
      end
      result.should == "sync return from the reactor thread"
      EM.next_tick { EM.stop }
    end
  end

  it "should run a block on the reactor thread using an optional callback" do
    with_em_and_thread do
      result = EM.schedule_sync do |promise|
        EM::Timer.new(1) {
          promise.deliver("async return from the reactor thread")
        }
      end
      result.should == "async return from the reactor thread"
      EM.next_tick { EM.stop }
    end
  end

  it "should rethrow exceptions in the calling thread" do
    result = nil
    with_em_and_thread do
      lambda {
        result = EM.schedule_sync do
          raise "blowup"
        end
      }.should raise_error(Exception, /blowup/)
      result.should == nil
      EM.next_tick { EM.stop }
    end
  end
end
