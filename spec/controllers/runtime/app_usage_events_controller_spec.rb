require "spec_helper"

module VCAP::CloudController
  describe AppUsageEventsController, type: :controller do
    before do
      app = AppFactory.make(package_hash: "abc", package_state: "STAGED")
      app.update(state: "STARTED")
    end

    describe "GET /v2/app_usage_events" do
      it "returns a list of app usage events" do
        get "/v2/app_usage_events", {}, admin_headers
        expect(last_response).to be_successful
        expect(decoded_response.fetch("resources")).to have(1).item
        expect(decoded_response.fetch("resources").first.fetch("entity")).to have_at_least(1).item
      end
    end
  end
end
