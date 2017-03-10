require 'spec_helper'

module VCAP::CloudController
  RSpec.describe ServiceUsageEventsController do
    let(:event_guid1) { SecureRandom.uuid }

    describe 'Query Parameters' do
      it { expect(described_class).to be_queryable_by(:service_instance_type) }
      it { expect(described_class).to be_queryable_by(:service_guid) }
    end

    before do
      ServiceUsageEvent.make(
        service_instance_type: 'managed_service_instance',
        guid: event_guid1
      )
      set_current_user_as_admin
    end

    after do
      ServiceUsageEvent.all.each(&:delete)
    end

    describe 'GET /v2/service_usage_events' do
      it 'returns a list of service usage events' do
        get '/v2/service_usage_events'
        expect(last_response).to be_successful
        expect(decoded_response.fetch('resources')).to have(1).item
        expect(decoded_response.fetch('resources').first.fetch('entity')).to have_at_least(1).item
      end

      context 'when filtering by after_guid' do
        let(:event_guid2) { SecureRandom.uuid }

        before do
          ServiceUsageEvent.make(guid: event_guid2)
          ServiceUsageEvent.make
        end

        it 'can filter by after_guid' do
          get "/v2/service_usage_events?after_guid=#{event_guid1}"
          expect(last_response).to be_successful
          expect(decoded_response.fetch('resources')).to have(2).item
          expect(decoded_response.fetch('resources').first.fetch('metadata').fetch('guid')).to eql(event_guid2)
        end

        it 'orders the events by event id' do
          get "/v2/service_usage_events?after_guid=#{event_guid1}"
          expect(last_response).to be_successful

          second_guid = decoded_response.fetch('resources').first.fetch('metadata').fetch('guid')
          third_guid = decoded_response.fetch('resources')[1].fetch('metadata').fetch('guid')

          second_event = ServiceUsageEvent.find(guid: second_guid)
          third_event = ServiceUsageEvent.find(guid: third_guid)

          expect(second_event.id).to be < third_event.id
        end

        it 'maintains the after_guid in the next_url' do
          get "/v2/service_usage_events?after_guid=#{event_guid1}&results-per-page=1"
          expect(last_response).to be_successful
          expect(decoded_response.fetch('next_url')).to eql("/v2/service_usage_events?after_guid=#{event_guid1}&order-direction=asc&page=2&results-per-page=1")
        end

        it 'maintains the after_guid in the prev_url' do
          get "/v2/service_usage_events?after_guid=#{event_guid1}&results-per-page=1&page=2"
          expect(last_response).to be_successful
          expect(decoded_response.fetch('prev_url')).to eql("/v2/service_usage_events?after_guid=#{event_guid1}&order-direction=asc&page=1&results-per-page=1")
        end

        it 'returns 400 when guid does not exist' do
          get '/v2/service_usage_events?after_guid=ABC'
          expect(last_response.status).to eql(400)
        end
      end

      context 'when filtering by service instance type' do
        before do
          ServiceUsageEvent.make(
            service_instance_type: 'user_provided_service_instance',
            service_plan_guid: nil,
            service_plan_name: nil,
            service_guid: nil,
            service_label: nil
          )
        end

        it 'returns a list of service usage events of managed_service_instance type only' do
          get '/v2/service_usage_events?q=service_instance_type:managed_service_instance'
          expect(last_response).to be_successful
          expect(decoded_response.fetch('resources')).to have(1).item
          expect(decoded_response.fetch('resources').first.fetch('entity')).to have_at_least(1).item
        end

        it 'returns a list of service usage events of user_provided_service_instance type only' do
          get '/v2/service_usage_events?q=service_instance_type:user_provided_service_instance'
          expect(last_response).to be_successful
          expect(decoded_response.fetch('resources')).to have(1).item
          expect(decoded_response.fetch('resources').first.fetch('entity')).to have_at_least(1).item
        end

        context 'and the response is multiple pages' do
          before do
            ServiceUsageEvent.make(service_instance_type: 'managed_service_instance')
            ServiceUsageEvent.make(service_instance_type: 'managed_service_instance')
            ServiceUsageEvent.make(service_instance_type: 'managed_service_instance')
          end

          it 'maintains the service_instance_type in the next_url' do
            get '/v2/service_usage_events?q=service_instance_type:managed_service_instance&results-per-page=1'
            expect(last_response).to be_successful
            expect(decoded_response.fetch('resources')).to have(1).item
            expect(decoded_response.fetch('next_url')).to include('/v2/service_usage_events')
            expect(decoded_response.fetch('next_url')).to include('service_instance_type:managed_service_instance')
            expect(decoded_response.fetch('next_url')).to include('order-direction=asc')
            expect(decoded_response.fetch('next_url')).to include('results-per-page=1')
          end

          it 'maintains the service_instance_type in the prev_url' do
            get '/v2/service_usage_events?q=service_instance_type:managed_service_instance&results-per-page=1&page=2'
            expect(last_response).to be_successful
            expect(decoded_response.fetch('prev_url')).to include('/v2/service_usage_events')
            expect(decoded_response.fetch('prev_url')).to include('service_instance_type:managed_service_instance')
            expect(decoded_response.fetch('prev_url')).to include('order-direction=asc')
            expect(decoded_response.fetch('prev_url')).to include('results-per-page=1')
          end
        end
      end

      context 'when filtering by service guid' do
        let(:service) { Service.make(:v2) }
        let!(:event) { ServiceUsageEvent.make(service_guid: service.guid) }

        it 'can filter by service_guid' do
          get "/v2/service_usage_events?q=service_guid:#{service.guid}"
          expect(last_response).to have_status_code 200
          expect(decoded_response.fetch('resources')).to have(1).item
          expect(decoded_response.fetch('resources').first['metadata']['guid']).to eq event.guid
        end

        context 'when the response is multiple pages' do
          let!(:event2) { ServiceUsageEvent.make(service_guid: service.guid) }

          it 'includes service_guid in the next_url' do
            get "/v2/service_usage_events?q=service_guid:#{service.guid}&results-per-page=1"
            expect(last_response).to have_status_code 200
            expect(decoded_response.fetch('resources')).to have(1).item
            expect(decoded_response.fetch('resources').first['metadata']['guid']).to eq event.guid

            expect(decoded_response['next_url']).to include("service_guid:#{service.guid}")
          end

          it 'includes service_guid in the prev_url' do
            get "/v2/service_usage_events?q=service_guid:#{service.guid}&results-per-page=1&page=2"
            expect(last_response).to have_status_code 200
            expect(decoded_response.fetch('resources')).to have(1).item
            expect(decoded_response.fetch('resources').first['metadata']['guid']).to eq event2.guid

            expect(decoded_response['prev_url']).to include("service_guid:#{service.guid}")
          end
        end
      end

      context 'when the user is not an admin (i.e. is not authorized)' do
        it 'returns 403' do
          set_current_user(User.make)
          get '/v2/service_usage_events'
          expect(last_response.status).to eq(403)
        end
      end
    end

    describe 'GET /v2/service_usage_events/:guid' do
      it 'retrieves an event by guid' do
        url = "/v2/service_usage_events/#{event_guid1}"
        get url
        expect(last_response).to be_successful
        expect(decoded_response['metadata']['guid']).to eq(event_guid1)
        expect(decoded_response['metadata']['url']).to eq(url)
      end

      it 'returns 403 as a non-admin' do
        set_current_user(User.make)
        url = "/v2/service_usage_events/#{event_guid1}"
        get url
        expect(last_response.status).to eq(403)
      end
    end

    describe 'POST /v2/service_usage_events/destructively_purge_all_and_reseed_existing_instance' do
      let(:user) { User.make }
      let(:instance) { ManagedServiceInstance.make }

      before do
        allow(ServiceUsageEvent.dataset).to receive(:truncate) do
          ServiceUsageEvent.dataset.destroy
        end
      end

      it 'purge all existing events' do
        expect(ServiceUsageEvent.count).not_to eq(0)

        post '/v2/service_usage_events/destructively_purge_all_and_reseed_existing_instances'

        expect(last_response.status).to eql(204)
        expect(ServiceUsageEvent.count).to eq(0)
      end

      it 'creates events for existing service instances' do
        reseed_time = Sequel.datetime_class.now
        instance.save

        post '/v2/service_usage_events/destructively_purge_all_and_reseed_existing_instances'

        expect(last_response).to be_successful
        expect(ServiceUsageEvent.count).to eq(1)
        expect(ServiceUsageEvent.last).to match_service_instance(instance)
        expect(ServiceUsageEvent.last.created_at.to_i).to be >= reseed_time.to_i
      end

      it 'returns 403 as a non-admin' do
        set_current_user(user)
        expect {
          post '/v2/service_usage_events/destructively_purge_all_and_reseed_existing_instances'
        }.to_not change {
          ServiceUsageEvent.count
        }

        expect(last_response.status).to eq(403)
      end
    end
  end
end
