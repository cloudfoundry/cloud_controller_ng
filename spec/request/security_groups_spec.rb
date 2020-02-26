require 'spec_helper'
require 'request_spec_shared_examples'

RSpec.describe 'Security_Groups Request' do
  let(:space) { VCAP::CloudController::Space.make }
  let(:org) { space.organization }
  let(:user) { VCAP::CloudController::User.make(guid: 'user-guid') }
  let(:admin_header) { admin_headers_for(user) }

  describe 'POST /v3/security_groups' do
    let(:api_call) { lambda { |user_headers| post '/v3/security_groups', params.to_json, user_headers } }

    context 'creating a security group' do
      let(:security_group_name) { 'security_group_name' }

      let(:params) do
        {
          'name': security_group_name,
          'globally_enabled': {
            'running': true,
            'staging': false
          }
        }
      end

      let(:expected_response) do
        {
          guid: UUID_REGEX,
          created_at: iso8601,
          updated_at: iso8601,
          name: security_group_name,
          globally_enabled: {
            'running': true,
            'staging': false
          },
          links: {
            self: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/security_groups\/#{UUID_REGEX}) },
          }
        }
      end

      let(:expected_codes_and_responses) do
        h = Hash.new(code: 403)
        h['admin'] = {
          code: 201,
          response_object: expected_response
        }
        h
      end

      it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS

      context 'when a security group with that name already exists' do
        before do
          post '/v3/security_groups', params.to_json, admin_header
        end

        it 'returns a 422 with a helpful message' do
          post '/v3/security_groups', params.to_json, admin_header

          expect(last_response).to have_status_code(422)
          expect(last_response).to have_error_message(
            "Security group with name '#{security_group_name}' already exists."
          )
        end
      end
    end
  end
end
