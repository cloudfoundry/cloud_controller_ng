require 'spec_helper'

module VCAP::CloudController
  describe VCAP::CloudController::BillingEventsController do
    let(:org) do
      Organization.make
    end

    let(:org_admin_headers) do
      user = User.make
      org.add_user(user)
      org.add_manager(user)
      headers_for(user)
    end

    before do
      BillingEvent.plugin :scissors
      BillingEvent.delete

      timestamp = Time.new(2012, 01, 01, 00, 00, 01).utc
      @start_time = timestamp

      @org_event = OrganizationStartEvent.make(
        timestamp: timestamp
      )

      @service_create_event = ServiceCreateEvent.make(
        timestamp: timestamp += 1
      )

      @service_delete_event = ServiceDeleteEvent.make(
        timestamp: timestamp += 1
      )

      @end_time = timestamp
    end

    describe 'enumerate' do
      it 'return 400 when no parameters are given' do
        get '/v2/billing_events', {}, admin_headers
        expect(last_response.status).to eq(400)
        expect(last_response).to be_a_deprecated_response
      end

      it 'requires an end_date parameter' do
        get "/v2/billing_events?start_date=#{@start_time.iso8601}", {}, admin_headers
        expect(last_response.status).to eq(400)
      end

      it 'requires a valid start_date parameter' do
        get "/v2/billing_events?start_date=bogus&end_date=#{@end_time.iso8601}", {}, admin_headers
        expect(last_response.status).to eq(400)
      end

      context 'with valid start and end date parameters' do
        let(:path) do
          '/v2/billing_events?' \
            "start_date=#{@start_time.utc.iso8601}" \
            "&end_date=#{@end_time.utc.iso8601}"
        end

        context 'as a cf admin' do
          it 'returns all records' do
            get path, {}, admin_headers
            expect(last_response.status).to eq(200)
            expect(decoded_response['total_results']).to eq(3)
            expect(decoded_response['total_pages']).to eq(1)
            expect(decoded_response['prev_url']).to eq(nil)
            expect(decoded_response['next_url']).to eq(nil)
            expect(decoded_response['resources'].size).to eq(3)
          end

          it 'correctly serializes the org billing start event' do
            get path, {}, admin_headers
            expect(decoded_response['resources'][0]).to eq({
              'event_type' => 'organization_billing_start',
              'organization_guid' => @org_event.organization_guid,
              'organization_name' => @org_event.organization_name,
              'timestamp' => @org_event.timestamp.iso8601,
            })
          end

          it 'correctly serializes the service create event' do
            get path, {}, admin_headers
            expect(decoded_response['resources'][1]).to eq({
              'event_type' => 'service_create',
              'organization_guid' => @service_create_event.organization_guid,
              'organization_name' => @service_create_event.organization_name,
              'space_guid' => @service_create_event.space_guid,
              'space_name' => @service_create_event.space_name,
              'service_instance_guid' => @service_create_event.service_instance_guid,
              'service_instance_name' => @service_create_event.service_instance_name,
              'service_guid' => @service_create_event.service_guid,
              'service_label' => @service_create_event.service_label,
              'service_provider' => @service_create_event.service_provider,
              'service_version' => @service_create_event.service_version,
              'service_plan_guid' => @service_create_event.service_plan_guid,
              'service_plan_name' => @service_create_event.service_plan_name,
              'timestamp' => @service_create_event.timestamp.iso8601,
            })
          end

          it 'correctly serializes the service delete event' do
            get path, {}, admin_headers
            expect(decoded_response['resources'][2]).to eq({
              'event_type' => 'service_delete',
              'organization_guid' => @service_delete_event.organization_guid,
              'organization_name' => @service_delete_event.organization_name,
              'space_guid' => @service_delete_event.space_guid,
              'space_name' => @service_delete_event.space_name,
              'service_instance_guid' => @service_delete_event.service_instance_guid,
              'service_instance_name' => @service_delete_event.service_instance_name,
              'timestamp' => @service_delete_event.timestamp.iso8601,
            })
          end
        end

        context 'as an org admin' do
          it 'return 0 records' do
            get path, {}, org_admin_headers
            expect(last_response.status).to eq(200)
            expect(decoded_response['total_results']).to eq(0)
            expect(decoded_response['resources'].size).to eq(0)
          end
        end
      end

      context 'when events are after of the end_date' do
        let(:path) do
          '/v2/billing_events?' \
            "start_date=#{@start_time.iso8601}" \
            "&end_date=#{(@end_time - 1).iso8601}"
        end

        it 'correctly filters events' do
          get path, {}, admin_headers
          expect(decoded_response['total_results']).to eq(2)
          expect(decoded_response['total_pages']).to eq(1)
          expect(decoded_response['prev_url']).to eq(nil)
          expect(decoded_response['next_url']).to eq(nil)
          expect(decoded_response['resources'].size).to eq(2)
        end
      end

      context 'when events are before of the start_date' do
        let(:path) do
          '/v2/billing_events?' \
            "start_date=#{(@start_time + 1).iso8601}" \
            "&end_date=#{@end_time.iso8601}"
        end

        it 'correctly filters them' do
          get path, {}, admin_headers
          expect(decoded_response['total_results']).to eq(2)
          expect(decoded_response['total_pages']).to eq(1)
          expect(decoded_response['prev_url']).to eq(nil)
          expect(decoded_response['next_url']).to eq(nil)
          expect(decoded_response['resources'].size).to eq(2)
        end
      end
    end
  end
end
