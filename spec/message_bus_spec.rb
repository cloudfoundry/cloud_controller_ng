# Copyright (c) 2009-2012 VMware, Inc.

require File.expand_path("../spec_helper", __FILE__)

module VCAP::CloudController
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

      it "should receive nats messages #{desc}" do
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

      it "should not leak exceptions into the defer block" do
        nats.should_receive(:subscribe).and_yield(msg_json, nil)

        logger = mock(:logger)
        logger.should_receive(:error)
        MessageBus.should_receive(:logger).and_return(logger)

        with_em_and_thread(:auto_stop => false) do
          EventMachine::Timer.new(0.1) { EM.stop }
          MessageBus.subscribe("foo") do
            raise "boom"
          end
        end
      end
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

    describe "request" do
      it "should use default expected value when not specified" do
        nats.should_receive(:request).once.with("subject", "abc",
                                                :max => 1)
        .and_yield(msg_json)

        with_em_and_thread do
          response = MessageBus.request("subject", "abc")
          response.should be_an_instance_of Array
          response.size.should == 1
          response.should == [msg_json]
        end
      end

      it "should use the specified expected value" do
        nats.should_receive(:request).once.with("subject", "abc",
                                                :max => 2)
        .and_yield(msg_json).and_yield(msg_json)

        with_em_and_thread do
          response = MessageBus.request("subject", "abc", :expected => 2)
          response.should be_an_instance_of Array
          response.size.should == 2
          response.should == [msg_json, msg_json]
        end
      end

      it "should not subscribe to nats when specified expected value is zero" do
        # We don't expect nats to receive anything.
        with_em_and_thread do
          response = MessageBus.request("subject", "abc", :expected => 0)
          response.should be_an_instance_of Array
          response.should == []
        end
      end

      it "should not register timeout with nats when none is specified" do
        nats.should_receive(:request).once.
          with("subject", "abc", :max => 1).and_yield(msg_json)

        nats.should_not_receive(:timeout)

        with_em_and_thread do
          response = MessageBus.request("subject", "abc")
          response.should be_an_instance_of Array
          response.size.should == 1
          response.should == [msg_json]
        end
      end

      it "should not register nats timeout with negative timeout value" do
        nats.should_receive(:request).once.
          with("subject", "abc", :max => 1).and_yield(msg_json)

        nats.should_not_receive(:timeout)

        with_em_and_thread do
          response = MessageBus.request("subject", "abc")
          response.should be_an_instance_of Array
          response.size.should == 1
          response.should == [msg_json]
        end
      end

      it "should register nats timeout" do
        # below, we are not yielding to the block supplied to the request.
        # this is to ensure that while in test promise.deliver(...) is called
        # exactly once by block supplied to nats timeout.
        nats.should_receive(:request).once.
          with("subject", "abc", :max => 1).and_return(1)

        nats.should_receive(:timeout).once.with(1, 0.1, :expected => 1).
          and_yield

        with_em_and_thread do
          response = MessageBus.request("subject", "abc", :timeout => 0.1)
          response.should be_an_instance_of Array
          response.size.should == 0
        end
      end
    end

    describe "process_message" do
      let(:msg) { Yajl::Encoder.encode({:a => 1, :b => 2}) }

      it "should pssed the parsed message and inbox to the block" do
        msg_received = nil
        inbox_received = nil

        block = proc do |msg, inbox|
          msg_received = msg
          inbox_received = inbox
        end

        MessageBus.send(:process_message, msg, "myinbox", &block)
        msg_received.should == {:a => 1, :b => 2}
        inbox_received.should == "myinbox"
      end

      it "should catch and log an error on an exception" do
        logger = mock(:logger)
        logger.should_receive(:error)
        MessageBus.should_receive(:logger).and_return(logger)

        block = proc do |msg, inbox|
          raise "boom"
        end

        MessageBus.send(:process_message, msg, "myinbox", &block)
      end
    end
  end
end
