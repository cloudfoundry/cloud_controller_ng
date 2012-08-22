# Copyright (c) 2009-2012 VMware, Inc.

require File.expand_path("../spec_helper", __FILE__)

describe VCAP::CloudController::MessageBus do
  let(:nats) { double(:nats) }

  let(:msg_json) do
    Yajl::Encoder.encode(:foo => "bar")
  end

  before do
    MessageBus.configure(:nats => nats)
  end

  shared_examples "subscription" do |receive_in_reactor|
    (desc, method) = if receive_in_reactor
                        ["on the reactor thread", :subscribe_on_reactor]
                      else
                        ["on a thread", :subscribe]
                      end

    it "should receive nasts messages #{desc}" do
      received_msg = false
      nats.should_receive(:subscribe).and_yield(msg_json, nil)
      with_em_and_thread(:auto_stop => false) do
        MessageBus.send(method, "some_subject") do |msg|
          EM.reactor_thread?.should == receive_in_reactor
          msg[:foo].should == "bar"
          received_msg = true
          EM.next_tick { EM.stop }
        end
      end
      received_msg.should == true
    end
  end

  describe "subscribe_on_reactor" do
    include_examples "subscription", true
  end

  describe "subscribe" do
    include_examples "subscription", false
  end

  describe "publish" do
    it "should publish to nats on the reactor thread" do
      published = false

      nats.should_receive(:publish).with("another_subject", "abc") do
        EM.reactor_thread?.should == true
        published = true
      end

      with_em_and_thread do
        MessageBus.publish("another_subject", "abc")
      end

      published.should == true
    end
  end
end
