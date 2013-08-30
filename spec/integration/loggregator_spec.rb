require "spec_helper"
require "securerandom"

module VCAP::CloudController
  describe "Cloud controller logs", :type => :integration do
    before(:all) do
      @loggregator_server = FakeLoggregatorServer.new(12345)
      @loggregator_server.start

      authed_headers = @authed_headers = {
          "Authorization" => "bearer #{admin_token}",
          "Accept" => "application/json",
          "Content-Type" => "application/json"
      }

      start_nats :debug => false
      start_cc(
          debug: false,
          config: "spec/fixtures/config/loggregator_config.yml"
      )

      org = make_post_request(
          "/v2/organizations",
          { "name" => "foo_org-#{SecureRandom.uuid}" }.to_json,
          authed_headers
      )
      org_guid = org.json_body["metadata"]["guid"]

      space = make_post_request(
          "/v2/spaces",
          { "name" => "foo_space",
            "organization_guid" => org_guid
          }.to_json,
          authed_headers
      )
      @space_guid = space.json_body["metadata"]["guid"]

      app = make_post_request(
          "/v2/apps",
          { "name" => "foo_app",
            "space_guid" => @space_guid
          }.to_json,
          authed_headers
      )

      @app_id = app.json_body["metadata"]["guid"]
    end

    after(:all) do
      stop_cc
      stop_nats
      @loggregator_server.stop(2)
    end

    it "to the loggregator" do
      messages = @loggregator_server.messages

      expect(messages.length).to eq 1

      message = messages[0]
      expect(message.message).to eq "Created app with guid #{@app_id}"
      expect(message.app_id).to eq @app_id
      expect(message.source_type).to eq LogMessage::SourceType::CLOUD_CONTROLLER
      expect(message.message_type).to eq LogMessage::MessageType::OUT
    end
  end
end
