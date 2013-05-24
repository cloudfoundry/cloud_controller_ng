# Copyright (c) 2009-2012 VMware, Inc.

require File.expand_path("../spec_helper", __FILE__)

module VCAP::CloudController
  describe VCAP::CloudController::MessageBus do
    let(:nats) do
      nats = double(:nats)
      nats.stub(:subscribe)
      nats.stub(:connected?)
      nats.stub(:on_error)
      nats.stub(:start) { |_, &blk| blk.call }
      nats.stub(:publish)
      nats.stub(:options) { {} }
      nats.stub(:wait_for_server)
      nats
    end
    let(:bus) { MessageBus.new(:nats => nats, :nats_uri => "nats://localhost:4222") }

    let(:msg) { {:foo => "bar"} }
    let(:msg_json) { Yajl::Encoder.encode(msg) }

    before { bus.stub(:register_cloud_controller) }

    describe "#subscribe" do
      it "should receive nats messages" do
        nats.should_receive(:subscribe).and_yield(msg_json, nil)
        was_on_reactor_thread = false
        received_msg = nil

        with_em_and_thread(:auto_stop => false) do
          bus.subscribe("some_subject") do |msg|
            was_on_reactor_thread = EM.reactor_thread?
            received_msg = msg
            EM.next_tick { EM.stop }
          end
        end

        was_on_reactor_thread.should be_false
        received_msg.should == msg
      end

      it "should not leak exceptions into the defer block" do
        nats.should_receive(:subscribe).and_yield(msg_json, nil)
        logger = mock(:logger)
        logger.should_receive(:error)
        bus.should_receive(:logger).and_return(logger)

        with_em_and_thread(:auto_stop => false) do
          EventMachine::Timer.new(0.1) { EM.stop }
          bus.subscribe("foo") do
            raise "boom"
          end
        end
      end

      it "should save subscriptions" do
        blk = lambda { puts "le bloc" }
        with_em_and_thread do
          bus.subscribe("eenee-meenee.moo", { :optional => true}, &blk)
        end

        bus.subscriptions.should include({"eenee-meenee.moo" => [ {:optional => true}, blk]})
      end
    end

    describe "#publish" do
      it "should publish to nats on the reactor thread" do
        published = false

        nats.should_receive(:publish).with("another_subject", "abc") do
          EM.reactor_thread?.should == true
          published = true
        end

        with_em_and_thread do
          bus.publish("another_subject", "abc")
        end

        published.should == true
      end
    end

    describe "#request" do
      it "should use default expected value when not specified" do
        nats.should_receive(:request)
          .once
          .with("subject", "abc", :max => 1)
          .and_yield(msg_json)

        with_em_and_thread do
          response = bus.request("subject", "abc")
          response.should be_an_instance_of Array
          response.size.should == 1
          response.should == [msg_json]
        end
      end

      it "should use the specified expected value" do
        nats.should_receive(:request)
          .once
          .with("subject", "abc", :max => 2)
          .and_yield(msg_json)
          .and_yield(msg_json)

        with_em_and_thread do
          response = bus.request("subject", "abc", :expected => 2)
          response.should be_an_instance_of Array
          response.size.should == 2
          response.should == [msg_json, msg_json]
        end
      end

      it "should not subscribe to nats when specified expected value is zero" do
        # We don't expect nats to receive anything.
        with_em_and_thread do
          response = bus.request("subject", "abc", :expected => 0)
          response.should be_an_instance_of Array
          response.should == []
        end
      end

      it "should not register timeout with nats when none is specified" do
        nats.should_receive(:request)
          .once
          .with("subject", "abc", :max => 1)
          .and_yield(msg_json)

        nats.should_not_receive(:timeout)

        with_em_and_thread do
          response = bus.request("subject", "abc")
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
          response = bus.request("subject", "abc")
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
          response = bus.request("subject", "abc", :timeout => 0.1)
          response.should be_an_instance_of Array
          response.size.should == 0
        end
      end
    end

    describe "#process_message" do
      let(:msg) { Yajl::Encoder.encode({:a => 1, :b => 2}) }

      it "should pssed the parsed message and inbox to the block" do
        msg_received = nil
        inbox_received = nil

        block = proc do |msg, inbox|
          msg_received = msg
          inbox_received = inbox
        end

        bus.send(:process_message, msg, "myinbox", &block)
        msg_received.should == {:a => 1, :b => 2}
        inbox_received.should == "myinbox"
      end

      it "should catch and log an error on an exception" do
        logger = mock(:logger)
        logger.should_receive(:error)
        bus.should_receive(:logger).and_return(logger)

        block = proc do |msg, inbox|
          raise "boom"
        end

        bus.send(:process_message, msg, "myinbox", &block)
      end
    end

    describe "#register_routes" do
      let(:config) { {
        :bind_address => '1.2.3.4',
        :port => 4222,
        :external_domain => ['ccng.vcap.me', 'api.vcap.me'],
        :nats => nats,
      } }

      let(:bus) { MessageBus.new(config) }

      let(:msg) { {
        :host => config[:bind_address],
        :port => config[:port],
        :uris => config[:external_domain],
        :tags => {:component => "CloudController"}
      } }

      it "subscribes to router.start and publishes router.register" do
        nats.should_receive(:subscribe).with("router.start").once

        nats.should_receive(:publish).once.
          with("router.register", msg_json)

        with_em_and_thread do
          bus.register_routes
        end
      end
    end

    describe "#unregister_routes" do
      let(:config) { {
        :bind_address => '1.2.3.4',
        :port => 4222,
        :external_domain => ['ccng.vcap.me', 'api.vcap.me'],
        :nats => nats,
      } }

      let(:bus) { MessageBus.new(config) }

      let(:msg) { {
        :host => config[:bind_address],
        :port => config[:port],
        :uris => config[:external_domain],
        :tags => {:component => "CloudController"}
      } }

      it "publishes router.unregister with the configured route" do
        nats.should_receive(:publish).once.
          with("router.unregister", msg_json)

        with_em_and_thread do
          bus.unregister_routes
        end
      end
    end

    describe "#register_components" do
      describe "nats goes down" do
        before do
          nats.stub(:on_error) { |&blk| blk.call }
          nats.stub(:start)
        end

        it "starts subscription recovery" do
          bus.should_receive(:start_nats_recovery)

          with_em_and_thread do
            bus.register_components
          end
        end

        it "registers nats downtime varz" do
          bus.should_receive(:update_nats_varz) do |time|
            time.should_not be_nil
            time.to_i.should be_within(2).of(Time.now.to_i)
          end

          with_em_and_thread do
            bus.register_components
          end
        end
      end
    end

    describe "#start_nats_recovery" do
      it "registers routes" do
        bus.should_receive(:register_routes)

        with_em_and_thread do
          bus.start_nats_recovery
        end
      end

      it "updates nats downtime varz" do
        bus.should_receive(:update_nats_varz) do |time|
          time.should be_nil
        end

        with_em_and_thread do
          bus.start_nats_recovery
        end
      end

      it "subscribes to every subjects" do
        blk1 = lambda {}
        blk2 = lambda {}
        blk3 = lambda {}

        bus.subscribe("hello.world", {}, &blk1)
        bus.subscribe("hello.milkyway", {}, &blk2)
        bus.subscribe("hello.universe", {}, &blk3)

        bus.should_receive(:subscribe).with("hello.world", {}, &blk1)
        bus.should_receive(:subscribe).with("hello.milkyway", {}, &blk2)
        bus.should_receive(:subscribe).with("hello.universe", {}, &blk3)

        with_em_and_thread do
          bus.start_nats_recovery
        end
      end

      it "registers legacy bulk subscription" do
        VCAP::CloudController::LegacyBulk.should_receive(:register_subscription)

        with_em_and_thread do
          bus.start_nats_recovery
        end
      end
    end
  end
end
