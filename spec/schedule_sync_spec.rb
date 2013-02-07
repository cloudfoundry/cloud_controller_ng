# Copyright (c) 2009-2012 VMware, Inc.

require File.expand_path("../spec_helper", __FILE__)
require "eventmachine"
require "eventmachine/schedule_sync"

describe "EventMachine#schedule_sync" do
  it "should run a block on the reactor thread and return the result" do
    result = nil
    with_em_and_thread do
      result = EM.schedule_sync do
        EM.reactor_thread?.should == true
        "sync return from the reactor thread"
      end
    end
    result.should == "sync return from the reactor thread"
  end

  it "should run a block on the reactor thread using an optional callback (async)" do
    result = nil
    with_em_and_thread do
      result = EM.schedule_sync do |promise|
        EM::Timer.new(1) {
          promise.deliver("async return from the reactor thread with timer")
        }
      end
    end
    result.should == "async return from the reactor thread with timer"
  end

  it "should run a block on the reactor thread using an optional callback (sync)" do
    result = nil
    with_em_and_thread do
      result = EM.schedule_sync do |promise|
        promise.deliver("async return from the reactor thread immediate")
      end
    end
    result.should == "async return from the reactor thread immediate"
  end

  it "should rethrow exceptions in the calling thread" do
    result = nil
    with_em_and_thread do
      expect {
        result = EM.schedule_sync do
          raise "blowup"
        end
      }.to raise_error(Exception, /blowup/)
    end
    result.should == nil
  end
end
