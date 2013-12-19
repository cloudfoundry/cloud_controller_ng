require "spec_helper"

module VCAP::CloudController
  describe AppUsageEventsController, type: :controller do
    before do
      @event1 = AppUsageEvent.make
    end

    describe "GET /v2/app_usage_events" do
      it "returns a list of app usage events" do
        get "/v2/app_usage_events", {}, admin_headers
        expect(last_response).to be_successful
        expect(decoded_response.fetch("resources")).to have(1).item
        expect(decoded_response.fetch("resources").first.fetch("entity")).to have_at_least(1).item
      end

      context "when filtering by after_guid" do
        before do
          @event2 = AppUsageEvent.make
          @event3 = AppUsageEvent.make
        end

        it "can filter by after_guid" do
          get "/v2/app_usage_events?after_guid=#{@event1.guid}", {}, admin_headers
          expect(last_response).to be_successful
          expect(decoded_response.fetch("resources")).to have(2).item
          expect(decoded_response.fetch("resources").first.fetch("metadata").fetch("guid")).to eql(@event2.guid)
        end

        it "maintains the after_guid in the next_url" do
          get "/v2/app_usage_events?after_guid=#{@event1.guid}&results-per-page=1", {}, admin_headers
          expect(last_response).to be_successful
          expect(decoded_response.fetch("next_url")).to eql("/v2/app_usage_events?after_guid=#{@event1.guid}&page=2&results-per-page=1")
        end

        it "maintains the after_guid in the prev_url" do
          get "/v2/app_usage_events?after_guid=#{@event1.guid}&results-per-page=1&page=2", {}, admin_headers
          expect(last_response).to be_successful
          expect(decoded_response.fetch("prev_url")).to eql("/v2/app_usage_events?after_guid=#{@event1.guid}&page=1&results-per-page=1")
        end

        it "returns 404 when guid does not exist" do
          get "/v2/app_usage_events?after_guid=ABC", {}, admin_headers
          expect(last_response.status).to eql(400)
        end
      end
    end
  end
end
