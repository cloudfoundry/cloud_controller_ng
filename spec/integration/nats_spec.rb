require "spec_helper"
require "nats/client"
require "json"

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
      make_get_request("/info").tap do |r|
        r.code.should == "200"
      end
    end

    describe "allowed requests" do
      let(:authorized_token) do
        {
          "Authorization" => "bearer #{admin_token}",
          "Accept" => "application/json",
          "Content-Type" => "application/json"
        }
      end

      after do
        make_delete_request("/v2/organizations/#{@org_guid}?recursive=true", authorized_token) if @org_guid
      end

      it "creates org, space and app in database" do
        data = %Q({"name":"nats-spec-org"})
        response = make_post_request("/v2/organizations", data, authorized_token)
        response.code.should == "201"
        @org_guid = response.json_body["metadata"]["guid"]

        data = %Q({"organization_guid":"#{@org_guid}","name":"nats-spec-space"})
        response = make_post_request("/v2/spaces", data, authorized_token)
        response.code.should == "201"
        @space_guid = response.json_body["metadata"]["guid"]

        data = %Q({
          "space_guid" : "#{@space_guid}",
          "name" : "nats-spec-app",
          "instances" : 1,
          "production" : false,
          "buildpack" : null,
          "command" : null,
          "memory" : 256,
          "stack_guid" : null
        })

        response = make_post_request("/v2/apps", data, authorized_token)
        response.code.should == "201"
      end
    end
  end

  describe "NATS fails and comes back up" do
    before(:all) do
      kill_nats
      sleep NATS::MAX_RECONNECT_ATTEMPTS * NATS::RECONNECT_TIME_WAIT + 1
      start_nats
      wait_for_nats_to_start
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
        NATS.timeout(sid, 10) { fail "NATS timed out while waiting for re-subscribe to propagate" }
      end
    end
  end
end