require File.expand_path("../spec_helper", __FILE__)

module VCAP::CloudController
  describe RouterClient do
    let(:configuration) do
      { :bind_address => "1.2.3.4",
        :port => 5678,
        :external_domain => "api.thebestcloud.com"
      }
    end

    let(:message_bus) { CfMessageBus::MockMessageBus.new }

    describe ".unregister" do
      before do
        RouterClient.setup(configuration, message_bus)
        EM.stub(:add_timer)
      end

      it "sends router.unregister over the message bus" do
        message_bus.should_receive(:publish).with(
            "router.unregister",
            hash_including(:host => "1.2.3.4",
                           :port => 5678,
                           :uris => "api.thebestcloud.com"))
        RouterClient.unregister
      end

      it "calls the callback, if provided" do
        called = false
        RouterClient.unregister do
          called = true
        end

        expect(called).to be_true
      end

      it "invokes the callback after 2 seconds due to timeout" do
        message_bus.stub(:publish) # don't yield
        EM.should_receive(:add_timer).with(RouterClient.message_bus_timeout).and_yield
        called = false
        RouterClient.unregister do
          called = true
        end
        expect(called).to be_true
      end

      it "only invokes the callback once" do
        EM.stub(:add_timer).with(RouterClient.message_bus_timeout).and_yield

        called = 0
        RouterClient.unregister do
          called += 1
        end
        expect(called).to eq(1)
      end
    end

    describe 'setup' do
      let(:setup) { RouterClient.setup(configuration, message_bus) }

      it 'should subscribe to router.start' do
        message_bus.should_receive(:subscribe).with("router.start")
        setup
      end

      context 'when router.start comes in' do
        it 'should publish router.register' do
          setup
          message_bus.stub(:publish).and_call_original
          message_bus.should_receive(:publish).with(
              "router.register",
              hash_including(:host => "1.2.3.4",
                             :port => 5678,
                             :uris => "api.thebestcloud.com"))

          message_bus.publish("router.start")
        end

        it 'should set up a periodic timer with router.register announcements' do
          setup
          EM.should_receive(:add_periodic_timer).with(22)

          message_bus.publish("router.start", {minimumRegisterIntervalInSeconds: 22})
        end

        it 'should clear an existing timer when registering a new one' do
          setup
          EM.should_receive(:add_periodic_timer).with(22).and_return(:hahaha)

          message_bus.publish("router.start", {minimumRegisterIntervalInSeconds: 22})

          EM.should_receive(:cancel_timer).with(:hahaha)
          EM.should_receive(:add_periodic_timer).with(55)
          message_bus.publish("router.start", {minimumRegisterIntervalInSeconds: 55})
        end
      end

      it 'should publish router.register immediately' do
        message_bus.should_receive(:publish).with(
            "router.register",
            hash_including(:host => "1.2.3.4",
                           :port => 5678,
                           :uris => "api.thebestcloud.com"))
        setup
      end

      it 'should recover by publishing router.register' do
        setup

        message_bus.should_receive(:publish).with(
            "router.register",
            hash_including(:host => "1.2.3.4",
                           :port => 5678,
                           :uris => "api.thebestcloud.com"))

        message_bus.do_recovery
      end
    end
  end
end