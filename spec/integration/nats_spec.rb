require "spec_helper"
require "nats/client"

describe "NATS", :type => :integration do
  before(:all) do
    start_nats
    start_cc(:env => {"NATS_MAX_RECONNECT_ATTEMPTS" => "0"})
  end

  after(:all) do
    stop_cc
    stop_nats
  end

  describe "When NATS fails" do
    before do
      kill_nats
    end

    it "still works" do
      make_http_request("/info").tap do |r|
        r.code.should == "200"
      end
    end

    it "doesn't create an app in the database"

    it "complains to VARZ"
  end

  describe "NATS fails and comes back up" do
    before(:all) do
      kill_nats
      start_nats
    end

    after(:all) do
      stop_nats
    end

    let(:router_register_message) do
      Yajl::Encoder.encode(
        {
          :host => "127.0.0.1",
          :port => 8181,
          :uris => "api2.vcap.me",
          :tags => {:component => "CloudController"}
        }
      )
    end

    it "re-subscribes" do
      NATS.start do
        sid = NATS.subscribe("router.register") do |received_msg|
          received_msg.should eq(router_register_message)
          NATS.stop
        end

        NATS.publish("router.start", {})
        NATS.timeout(sid, 5) { fail "NATS timed out while waiting for re-subscribe to propagate" }
      end
    end
  end
end