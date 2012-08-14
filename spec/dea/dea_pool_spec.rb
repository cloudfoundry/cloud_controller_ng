# Copyright (c) 2009-2012 VMware, Inc.

require File.expand_path("../spec_helper", __FILE__)

describe VCAP::CloudController::DeaPool do
  let(:message_bus) { double(:message_bus) }

  let(:dea_msg) do
    {
      :id => "abc",
      :available_memory => 1024,
      :runtimes => ["ruby18", "java"]
    }
  end

  before do
    DeaPool.configure(config, message_bus)
  end

  describe "process_advertise_message" do

    it "should add a dea profile with a recent timestamp" do
      deas = DeaPool.send(:deas)
      deas.count.should == 0
      DeaPool.send(:process_advertise_message, dea_msg)
      deas.count.should == 1
      deas.should have_key("abc")

      dea = deas["abc"]
      dea[:advertisement].should == dea_msg
      dea[:last_update].should be_recent
    end
  end

  describe "subscription"  do
    it "should respond to dea.advertise" do
      message_bus.should_receive(:subscribe).and_yield(dea_msg)
      DeaPool.should_receive(:process_advertise_message).with(dea_msg)
      DeaPool.register_subscriptions
    end
  end

  describe "find_dea" do
    # meets needs but will be setup to be expired
    let(:dea_a) do
      {
        :id => "a",
        :available_memory => 1024,
        :runtimes => ["ruby18", "java", "ruby19"]
      }
    end

    # meets mem needs only
    let(:dea_b) do
      {
        :id => "b",
        :available_memory => 1024,
        :runtimes => ["ruby18", "java"]
      }
    end

    # meets runtime needs only
    let(:dea_c) do
      {
        :id => "c",
        :available_memory => 512,
        :runtimes => ["ruby18", "java", "ruby19"]
      }
    end

    # meets all needs
    let(:dea_d) do
      {
        :id => "d",
        :available_memory => 1024,
        :runtimes => ["ruby18", "java", "ruby19"]
      }
    end

    let(:deas) do
      deas = DeaPool.send(:deas)
    end

    before do
      DeaPool.send(:process_advertise_message, dea_a)
      DeaPool.send(:process_advertise_message, dea_b)
      DeaPool.send(:process_advertise_message, dea_c)
      DeaPool.send(:process_advertise_message, dea_d)
      deas["a"][:last_update] = Time.new(2011, 04, 11)
    end

    it "should find a non-expired dea meeting the needs of the app" do
      deas["a"][:last_update] = Time.new(2011, 04, 11)
      id = DeaPool.find_dea(1024, "ruby19")
      id.should == "d"
    end

    it "should remove expired dea entries" do
      deas.count.should == 4
      id = DeaPool.find_dea(4096, "cobol")
      id.should == nil
      deas.count.should == 3
    end
  end
end
