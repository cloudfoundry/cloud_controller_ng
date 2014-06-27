require "spec_helper"
require "securerandom"

module VCAP::CloudController
  describe "Cloud controller app event registration", type: :integration do
    before(:all) do
      authed_headers = @authed_headers = {
        "Authorization" => "bearer #{admin_token}",
        "Accept" => "application/json",
        "Content-Type" => "application/json"
      }

      start_nats :debug => false

      start_cc(
        debug: false,
        config: "spec/fixtures/config/port_8181_config.yml"
      )
      start_cc(
        debug: false,
        config: "spec/fixtures/config/port_8182_config.yml",
        preserve_database: true
      )

      org = org_with_default_quota(authed_headers)
      org_guid = org.json_body["metadata"]["guid"]

      space = make_post_request(
        "/v2/spaces",
        {
          "name" => "foo_space",
          "organization_guid" => org_guid
        }.to_json,
        authed_headers
      )
      space_guid = space.json_body["metadata"]["guid"]

      @app = make_post_request(
        "/v2/apps",
        {
          "name" => "foo_app",
          "space_guid" => space_guid
        }.to_json,
        authed_headers
      ).json_body
    end

    after(:all) do
      stop_cc
      stop_nats
    end

    let(:payload) do
      {
        droplet: @app["metadata"]["guid"],
        reason: "CRASHED",
        instance: "foo",
        index: 0,
        exit_status: 42,
        exit_description: "because i said so"
      }
    end

    def registered_events
      make_get_request(
        "/v2/apps/#{@app["metadata"]["guid"]}/events",
        @authed_headers
      ).json_body["resources"]
    end

    it "registers only one app event in response to droplet.exited" do
      expect {
        NATS.start do
          NATS.publish("droplet.exited", payload.to_json) do
            NATS.stop
          end
        end

        sleep 1
      }.to change { registered_events.size }.from(0).to(1)
    end
  end
end
