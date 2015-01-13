require 'spec_helper'

module VCAP::CloudController
  describe AppUsageEventsController do
    before do
      @event1 = AppUsageEvent.make
    end

    describe 'GET /v2/app_usage_events' do
      it 'returns a list of app usage events' do
        get '/v2/app_usage_events', '{}', admin_headers
        expect(last_response).to be_successful
        expect(decoded_response.fetch('resources')).to have(1).item
        expect(decoded_response.fetch('resources').first.fetch('entity')).to have_at_least(1).item
      end

      context 'when filtering by after_guid' do
        before do
          @event2 = AppUsageEvent.make
          @event3 = AppUsageEvent.make
        end

        it 'can filter by after_guid' do
          get "/v2/app_usage_events?after_guid=#{@event1.guid}", '{}', admin_headers
          expect(last_response).to be_successful
          expect(decoded_response.fetch('resources')).to have(2).item
          expect(decoded_response.fetch('resources').first.fetch('metadata').fetch('guid')).to eql(@event2.guid)
        end

        it 'maintains the after_guid in the next_url' do
          get "/v2/app_usage_events?after_guid=#{@event1.guid}&results-per-page=1", '{}', admin_headers
          expect(last_response).to be_successful
          expect(decoded_response.fetch('next_url')).to eql("/v2/app_usage_events?after_guid=#{@event1.guid}&order-direction=asc&page=2&results-per-page=1")
        end

        it 'maintains the after_guid in the prev_url' do
          get "/v2/app_usage_events?after_guid=#{@event1.guid}&results-per-page=1&page=2", '{}', admin_headers
          expect(last_response).to be_successful
          expect(decoded_response.fetch('prev_url')).to eql("/v2/app_usage_events?after_guid=#{@event1.guid}&order-direction=asc&page=1&results-per-page=1")
        end

        it 'returns 400 when guid does not exist' do
          get '/v2/app_usage_events?after_guid=ABC', '{}', admin_headers
          expect(last_response.status).to eql(400)
        end
      end
    end

    describe 'GET /v2/app_usage_events/:guid' do
      it 'retrieves an event by guid' do
        url = "/v2/app_usage_events/#{@event1.guid}"
        get url, '{}', admin_headers
        expect(last_response).to be_successful
        expect(decoded_response['metadata']['guid']).to eq(@event1.guid)
        expect(decoded_response['metadata']['url']).to eq(url)
      end

      it 'returns 404 when he guid does nos exist' do
        get '/v2/app_usage_events/bogus', '{}', admin_headers
        expect(last_response.status).to eql(404)
      end
    end

    describe 'POST /v2/app_usage_events/destructively_purge_all_and_reseed_started_apps' do
      before do
        # Truncate in mysql causes an implicit commit.
        # This stub will cause the same behavior, but not commit.
        allow(AppUsageEvent.dataset).to receive(:truncate) do
          AppUsageEvent.dataset.delete
        end
      end

      it 'purge all existing events' do
        expect(AppUsageEvent.count).not_to eq(0)
        post '/v2/app_usage_events/destructively_purge_all_and_reseed_started_apps', '{}', admin_headers
        expect(last_response.status).to eql(204)
        expect(AppUsageEvent.count).to eq(0)
      end

      it 'creates events for existing STARTED apps' do
        app = AppFactory.make(state: 'STARTED', package_hash: Sham.guid)
        AppFactory.make(state: 'STOPPED')
        post '/v2/app_usage_events/destructively_purge_all_and_reseed_started_apps', '{}', admin_headers
        expect(last_response).to be_successful
        expect(AppUsageEvent.count).to eq(1)
        expect(AppUsageEvent.last).to match_app(app)
        expect(AppUsageEvent.last.created_at).to be_within(5.seconds).of(Time.now.utc)
      end

      it 'returns 403 as a non-admin' do
        user = User.make
        expect {
          post '/v2/app_usage_events/destructively_purge_all_and_reseed_started_apps', '{}', headers_for(user)
        }.to_not change {
          AppUsageEvent.count
        }
        expect(last_response.status).to eq(403)
      end
    end
  end
end
