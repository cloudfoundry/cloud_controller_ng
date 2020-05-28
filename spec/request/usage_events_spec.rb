require 'spec_helper'
require 'request_spec_shared_examples'

RSpec.describe 'Events' do
  describe 'GET /v3/usage_events/:guid' do
    let(:user) { make_user }
    let(:admin_header) { admin_headers_for(user) }
    let(:space) { VCAP::CloudController::Space.make }
    let(:org) { space.organization }
    let(:api_call) { lambda { |user_headers| get "/v3/usage_events/#{usage_event.guid}", nil, user_headers } }

    context 'when the audit_event exists' do
      let(:usage_event) {
        VCAP::CloudController::AppUsageEvent.make
      }

      let(:usage_event_json) do
        {
          'guid' => usage_event.guid,
          'created_at' => iso8601,
          'updated_at' => iso8601,
          'type' => 'app',
        }
      end

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
    end

    context 'when the audit_event does not exist' do
      it 'returns a 404' do
        get '/v3/usage_events/does-not-exist', nil, admin_header
        expect(last_response.status).to eq 404
        expect(last_response).to have_error_message('Usage event not found')
      end
    end

    context 'when the user is not logged in' do
      let(:usage_event) {
        VCAP::CloudController::AppUsageEvent.make
      }

      it 'returns 401 for Unauthenticated requests' do
        get "/v3/usage_events/#{usage_event.guid}", nil, base_json_headers
        expect(last_response.status).to eq(401)
      end
    end
  end
end
