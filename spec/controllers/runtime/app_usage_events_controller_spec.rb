require "spec_helper"

module VCAP::CloudController
  describe AppUsageEventsController, type: :controller do
    before do
      @event1 = AppUsageEvent.make
      @event2 = AppUsageEvent.make
    end

    describe "GET /v2/app_usage_events" do
      it "returns a list of app usage events in correct order" do
        get "/v2/app_usage_events", {}, admin_headers
        expect(last_response).to be_successful
        expect(decoded_response.fetch("resources")).to have_at_least(1).item
        expect(decoded_response.fetch("resources").first.fetch("entity")).to have_at_least(1).item
        guids = decoded_response.fetch("resources").collect do |item|
          item["metadata"]["guid"]
        end
        expect(guids.find_index(@event1.guid)).to be < guids.find_index(@event2.guid)
      end

      context "when filtering by after_guid" do
        before do
          Timecop.travel(Time.now + 5.minutes) do
            @event3 = AppUsageEvent.make
            @event4 = AppUsageEvent.make
          end
        end

        it "can filter by after_guid to return events happended after the specified event" do
          get "/v2/app_usage_events?after_guid=#{@event2.guid}", {}, admin_headers
          expect(last_response).to be_successful
          event_timestamps = decoded_response.fetch("resources").collect{ |resource| resource.fetch("metadata").fetch("created_at") }
          event_timestamps.each do |timestamp|
            expect(Time.parse(timestamp)).to be > (@event2.created_at)
          end
        end

        it "maintains the after_guid in the next_url" do
          get "/v2/app_usage_events?after_guid=#{@event1.guid}&results-per-page=1", {}, admin_headers
          expect(last_response).to be_successful
          expect(decoded_response.fetch("next_url")).to eql("/v2/app_usage_events?after_guid=#{@event1.guid}&order-direction=asc&page=2&results-per-page=1")
        end

        it "maintains the after_guid in the prev_url" do
          get "/v2/app_usage_events?after_guid=#{@event1.guid}&results-per-page=1&page=2", {}, admin_headers
          expect(last_response).to be_successful
          expect(decoded_response.fetch("prev_url")).to eql("/v2/app_usage_events?after_guid=#{@event1.guid}&order-direction=asc&page=1&results-per-page=1")
        end

        it "returns 400 when guid does not exist" do
          get "/v2/app_usage_events?after_guid=ABC", {}, admin_headers
          expect(last_response.status).to eql(400)
        end
      end
    end

    describe "GET /v2/app_usage_events/:guid" do
      it "retrieves an event by guid" do
        url = "/v2/app_usage_events/#{@event1.guid}"
        get url, {}, admin_headers
        expect(last_response).to be_successful
        expect(decoded_response["metadata"]["guid"]).to eq(@event1.guid)
        expect(decoded_response["metadata"]["url"]).to eq(url)
      end

      it "returns 404 when he guid does nos exist" do
        get "/v2/app_usage_events/bogus", {}, admin_headers
        expect(last_response.status).to eql(404)
      end
    end

    describe "POST /v2/app_usage_events/destructively_purge_all_and_reseed_started_apps", non_transactional: true do
      it "purge all existing events" do
        expect(AppUsageEvent.count).not_to eq(0)
        post "/v2/app_usage_events/destructively_purge_all_and_reseed_started_apps", {}, admin_headers
        expect(last_response.status).to eql(204)
        expect(AppUsageEvent.count).to eq(0)
      end

      it "creates events for existing STARTED apps" do
        app = AppFactory.make(state: "STARTED", package_hash: Sham.guid)
        AppFactory.make(state: "STOPPED")
        post "/v2/app_usage_events/destructively_purge_all_and_reseed_started_apps", {}, admin_headers
        expect(last_response).to be_successful
        expect(AppUsageEvent.count).to eq(1)
        expect(AppUsageEvent.last).to match_app(app)
        expect(AppUsageEvent.last.created_at).to be_within(5.seconds).of(Time.now)
      end

      it "returns 403 as a non-admin" do
        user = User.make
        post "/v2/app_usage_events/destructively_purge_all_and_reseed_started_apps", {}, headers_for(user)
        expect(last_response.status).to eq(403)
      end
    end
  end
end
