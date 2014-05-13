require 'spec_helper'

module VCAP::CloudController
  describe ServiceUsageEventsController, type: :controller do
    before do
      @event1 = ServiceUsageEvent.make({
                                         service_instance_type: 'managed_service_instance'
                                       })
    end

    describe 'GET /v2/service_usage_events' do
      it 'returns a list of service usage events' do
        get '/v2/service_usage_events', {}, admin_headers
        expect(last_response).to be_successful
        expect(decoded_response.fetch('resources')).to have(1).item
        expect(decoded_response.fetch('resources').first.fetch('entity')).to have_at_least(1).item
      end

      context 'when filtering by after_guid' do
        before do
          @event2 = ServiceUsageEvent.make
          @event3 = ServiceUsageEvent.make
        end

        it 'can filter by after_guid' do
          get "/v2/service_usage_events?after_guid=#{@event1.guid}", {}, admin_headers
          expect(last_response).to be_successful
          expect(decoded_response.fetch('resources')).to have(2).item
          expect(decoded_response.fetch('resources').first.fetch('metadata').fetch('guid')).to eql(@event2.guid)
        end

        it 'orders the events by event id' do
          get "/v2/service_usage_events?after_guid=#{@event1.guid}", {}, admin_headers
          expect(last_response).to be_successful

          second_guid = decoded_response.fetch('resources').first.fetch('metadata').fetch('guid')
          third_guid = decoded_response.fetch('resources')[1].fetch('metadata').fetch('guid')

          second_event = ServiceUsageEvent.find(guid: second_guid)
          third_event = ServiceUsageEvent.find(guid: third_guid)

          expect(second_event.id).to be < third_event.id
        end

        it 'maintains the after_guid in the next_url' do
          get "/v2/service_usage_events?after_guid=#{@event1.guid}&results-per-page=1", {}, admin_headers
          expect(last_response).to be_successful
          expect(decoded_response.fetch('next_url')).to eql("/v2/service_usage_events?after_guid=#{@event1.guid}&order-direction=asc&page=2&results-per-page=1")
        end

        it 'maintains the after_guid in the prev_url' do
          get "/v2/service_usage_events?after_guid=#{@event1.guid}&results-per-page=1&page=2", {}, admin_headers
          expect(last_response).to be_successful
          expect(decoded_response.fetch('prev_url')).to eql("/v2/service_usage_events?after_guid=#{@event1.guid}&order-direction=asc&page=1&results-per-page=1")
        end

        it 'returns 400 when guid does not exist' do
          get '/v2/service_usage_events?after_guid=ABC', {}, admin_headers
          expect(last_response.status).to eql(400)
        end
      end

      context 'when filtering by service instance type' do
        before do
          @event2 = ServiceUsageEvent.make({
                                             service_instance_type: 'user_provided_service_instance',
                                             service_plan_guid: nil,
                                             service_plan_name: nil,
                                             service_guid: nil,
                                             service_label: nil
                                           })
        end

        it 'returns a list of service usage events of managed_service_instance type only' do
          get '/v2/service_usage_events?q=service_instance_type:managed_service_instance', {}, admin_headers
          expect(last_response).to be_successful
          expect(decoded_response.fetch('resources')).to have(1).item
          expect(decoded_response.fetch('resources').first.fetch('entity')).to have_at_least(1).item
        end

        it 'returns a list of service usage events of user_provided_service_instance type only' do
          get '/v2/service_usage_events?q=service_instance_type:user_provided_service_instance', {}, admin_headers
          expect(last_response).to be_successful
          expect(decoded_response.fetch('resources')).to have(1).item
          expect(decoded_response.fetch('resources').first.fetch('entity')).to have_at_least(1).item
        end
      end

      context 'when the user has not authenticated with Cloud Controller' do
        let(:developer) { nil }

        it 'returns 401' do
          get '/v2/service_usage_events', {}, json_headers(headers_for(developer))
          expect(last_response.status).to eq(401)
        end
      end

      context 'when the user is not an admin (i.e. is not authorized)' do
        it 'returns 403' do
          user_headers = headers_for(VCAP::CloudController::User.make(:admin => false))
          get '/v2/service_usage_events', {}, json_headers(user_headers)
          expect(last_response.status).to eq(403)
        end
      end

    end

    describe 'GET /v2/service_usage_events/:guid' do
      it 'retrieves an event by guid' do
        url = "/v2/service_usage_events/#{@event1.guid}"
        get url, {}, admin_headers
        expect(last_response).to be_successful
        expect(decoded_response['metadata']['guid']).to eq(@event1.guid)
        expect(decoded_response['metadata']['url']).to eq(url)
      end

      it 'returns 404 when he guid does nos exist' do
        get '/v2/service_usage_events/bogus', {}, admin_headers
        expect(last_response.status).to eql(404)
      end
    end
  end
end
