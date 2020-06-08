require 'spec_helper'
require 'request_spec_shared_examples'

RSpec.describe 'Service Usage Events' do
  let(:user) { make_user }
  let(:admin_header) { admin_headers_for(user) }
  let(:space) { VCAP::CloudController::Space.make }
  let(:org) { space.organization }

  describe 'GET /v3/service_usage_events/:guid' do
    let(:api_call) { lambda { |user_headers| get "/v3/service_usage_events/#{usage_event.guid}", nil, user_headers } }

    let(:usage_event) { VCAP::CloudController::ServiceUsageEvent.make }

    let(:usage_event_json) { build_usage_event_json(usage_event) }

    let(:expected_codes_and_responses) do
      h = Hash.new(
        code: 404,
        response_object: []
      )
      h['admin'] = {
        code: 200,
        response_object: usage_event_json
      }
      h['admin_read_only'] = {
        code: 200,
        response_object: usage_event_json
      }
      h['global_auditor'] = {
        code: 200,
        response_object: usage_event_json
      }
      h.freeze
    end

    it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS

    context 'when the usage event does not exist' do
      it 'returns a 404' do
        get '/v3/service_usage_events/does-not-exist', nil, admin_header
        expect(last_response.status).to eq 404
        expect(last_response).to have_error_message('Service usage event not found')
      end
    end

    context 'when the user is not logged in' do
      it 'returns 401 for Unauthenticated requests' do
        get "/v3/service_usage_events/#{usage_event.guid}", nil, base_json_headers
        expect(last_response.status).to eq(401)
      end
    end
  end

  describe 'GET /v3/service_usage_events' do
    let(:api_call) { lambda { |user_headers| get '/v3/service_usage_events', nil, user_headers } }

    let!(:service_usage_event) do
      VCAP::CloudController::ServiceUsageEvent.make(
        created_at: Time.now,
        service_instance_type: 'managed_service_instance',
        service_guid: 'offering-guid'
      )
    end

    let!(:service_usage_event_2) do
      VCAP::CloudController::ServiceUsageEvent.make(
        created_at: Time.now,
        service_instance_type: 'user_provided_service_instance',
        service_guid: 'offering-guid-2'
      )
    end

    let(:service_usage_event_json) { build_usage_event_json(service_usage_event) }
    let(:service_usage_event_2_json) { build_usage_event_json(service_usage_event_2) }

    let(:expected_codes_and_responses) do
      h = Hash.new(
        code: 200,
        response_objects: []
      )
      h['admin'] = {
        code: 200,
        response_objects: [service_usage_event_json, service_usage_event_2_json]
      }
      h['admin_read_only'] = {
        code: 200,
        response_objects: [service_usage_event_json, service_usage_event_2_json]
      }
      h['global_auditor'] = {
        code: 200,
        response_objects: [service_usage_event_json, service_usage_event_2_json]
      }
      h.freeze
    end

    it_behaves_like 'permissions for list endpoint', ALL_PERMISSIONS

    context 'when the user is not logged in' do
      it 'returns 401 for Unauthenticated requests' do
        get '/v3/service_usage_events', nil, base_json_headers
        expect(last_response.status).to eq(401)
      end
    end

    context 'when using the after_guid filter' do
      it 'returns the usage event matching the requested guid' do
        get "/v3/service_usage_events?after_guid=#{service_usage_event.guid}", nil, admin_headers
        expect(last_response).to have_status_code(200)
        expect(parsed_response['resources'].length).to eq(1)
        expect(parsed_response['resources'][0]).to match_json_response(service_usage_event_2_json)
      end
    end

    context 'when using the guids filter' do
      it 'returns the usage event matching the requested guid' do
        get "/v3/service_usage_events?guids=#{service_usage_event_2.guid}", nil, admin_headers
        expect(last_response).to have_status_code(200)
        expect(parsed_response['resources'].length).to eq(1)
        expect(parsed_response['resources'][0]).to match_json_response(service_usage_event_2_json)
      end
    end

    context 'when using the service_instance_types filter' do
      it 'returns the usage event matching the requested service instance type' do
        get "/v3/service_usage_events?service_instance_types=#{service_usage_event.service_instance_type}", nil, admin_headers
        expect(last_response).to have_status_code(200)
        expect(parsed_response['resources'].length).to eq(1)
        expect(parsed_response['resources'][0]).to match_json_response(service_usage_event_json)
      end
    end

    context 'when using the service_offering_guids filter' do
      it 'returns the usage event matching the requested service offering guid' do
        get "/v3/service_usage_events?service_offering_guids=#{service_usage_event.service_guid}", nil, admin_headers
        expect(last_response).to have_status_code(200)
        expect(parsed_response['resources'].length).to eq(1)
        expect(parsed_response['resources'][0]).to match_json_response(service_usage_event_json)
      end
    end

    context 'when using an invalid filter' do
      it 'returns a 422 with a helpful message' do
        get '/v3/service_usage_events?garbage=true', nil, admin_headers
        expect(last_response).to have_status_code(422)
        expect(last_response).to have_error_message("Unknown query parameter(s): 'garbage'.")
      end
    end
  end

  describe 'POST /v3/service_usage_events/actions/destructively_purge_all_and_reseed' do
    let(:api_call) { lambda { |user_headers| post '/v3/service_usage_events/actions/destructively_purge_all_and_reseed', nil, user_headers } }

    let!(:service_instance) do
      VCAP::CloudController::ServiceInstance.make
    end

    let!(:usage_event) do
      VCAP::CloudController::ServiceUsageEvent.make(guid: 'some-guid')
    end

    let(:expected_codes_and_responses) do
      h = Hash.new(code: 403)
      h['admin'] = { code: 200 }
      h.freeze
    end

    it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS do
      let(:after_request_check) do
        lambda do
          expect(VCAP::CloudController::ServiceUsageEvent.all.count).to eq(1)
          expect(VCAP::CloudController::ServiceUsageEvent.find(guid: 'some-guid')).to be_nil
          expect(VCAP::CloudController::ServiceUsageEvent.where(service_instance_guid: service_instance.guid).count).to eq(1)
        end
      end
    end
  end

  def build_usage_event_json(service_usage_event)
    {
      'guid' => service_usage_event.guid,
      'created_at' => iso8601,
      'updated_at' => iso8601,
      'state' => service_usage_event.state,
      'space' => {
        'guid' => service_usage_event.space_guid,
        'name' => service_usage_event.space_name,
      },
      'organization' => {
        'guid' => service_usage_event.org_guid,
      },
      'service_instance' => {
        'guid' => service_usage_event.service_instance_guid,
        'name' => service_usage_event.service_instance_name,
        'type' => service_usage_event.service_instance_type,
      },
      'service_plan' => {
        'guid' => service_usage_event.service_plan_guid,
        'name' => service_usage_event.service_plan_name,
      },
      'service_offering' => {
        'guid' => service_usage_event.service_guid,
        'name' => service_usage_event.service_label,
      },
      'service_broker' => {
        'guid' => service_usage_event.service_broker_guid,
        'name' => service_usage_event.service_broker_name,
      }
    }
  end
end
