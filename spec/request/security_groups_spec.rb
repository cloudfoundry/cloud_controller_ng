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

  describe 'GET /v3/security_groups/:guid' do
    let(:api_call) { lambda { |user_headers| get "/v3/security_groups/#{security_group.guid}", nil, user_headers } }

    context 'getting a security group NOT globally enabled NOR associated with any spaces' do
      let(:security_group) { VCAP::CloudController::SecurityGroup.make }

      let(:expected_response) do
        {
          guid: security_group.guid,
          created_at: iso8601,
          updated_at: iso8601,
          name: security_group.name,
          globally_enabled: {
            running: false,
            staging: false
          },
          links: {
            self: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/security_groups\/#{UUID_REGEX}) },
          }
        }
      end

      let(:expected_codes_and_responses) do
        h = Hash.new(code: 404)
        h['admin'] = {
          code: 200,
          response_object: expected_response
        }
        h['admin_read_only'] = {
          code: 200,
          response_object: expected_response
        }
        h['global_auditor'] = {
          code: 200,
          response_object: expected_response
        }
        h
      end

      it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS
    end

    context 'getting a security group NOT globally enabled, associated with spaces' do
      let(:security_group) { VCAP::CloudController::SecurityGroup.make }

      before do
        security_group.add_staging_space(space)
      end

      let(:expected_response) do
        {
          guid: security_group.guid,
          created_at: iso8601,
          updated_at: iso8601,
          name: security_group.name,
          globally_enabled: {
            running: false,
            staging: false
          },
          links: {
            self: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/security_groups\/#{UUID_REGEX}) },
          }
        }
      end

      let(:expected_codes_and_responses) do
        h = Hash.new(code: 404)
        h['admin'] = {
          code: 200,
          response_object: expected_response
        }
        h['admin_read_only'] = {
          code: 200,
          response_object: expected_response
        }
        h['global_auditor'] = {
          code: 200,
          response_object: expected_response
        }
        h['space_developer'] = {
          code: 200,
          response_object: expected_response
        }
        h['space_manager'] = {
          code: 200,
          response_object: expected_response
        }
        h['space_auditor'] = {
          code: 200,
          response_object: expected_response
        }
        h['org_manager'] = {
          code: 200,
          response_object: expected_response
        }
        h
      end

      it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS
    end

    context 'getting a security group globally enabled' do
      let(:security_group) { VCAP::CloudController::SecurityGroup.make(running_default: true) }

      let(:expected_response) do
        {
          guid: security_group.guid,
          created_at: iso8601,
          updated_at: iso8601,
          name: security_group.name,
          globally_enabled: {
            running: true,
            staging: false
          },
          links: {
            self: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/security_groups\/#{UUID_REGEX}) },
          }
        }
      end

      let(:expected_codes_and_responses) do
        Hash.new(code: 200, response_object: expected_response)
      end

      it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS
    end

    context 'security group does not exist' do
      it 'returns a 404 with a helpful message' do
        get '/v3/security_groups/fake-security-group', nil, admin_header

        expect(last_response).to have_status_code(404)
        expect(last_response).to have_error_message(
          'Security group not found'
        )
      end
    end
  end
end
