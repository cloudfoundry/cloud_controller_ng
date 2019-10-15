require 'spec_helper'
require 'request_spec_shared_examples'

RSpec.describe 'Roles Request' do
  let(:user) { VCAP::CloudController::User.make }
  let(:admin_header) { admin_headers_for(user) }
  let(:space) { VCAP::CloudController::Space.make }
  let(:org) { space.organization }
  let(:user_with_role) { VCAP::CloudController::User.make }
  let(:user_guid) { user.guid }
  let(:space_guid) { space.guid }

  describe 'POST /v3/roles' do
    let(:api_call) { lambda { |user_headers| post '/v3/roles', params.to_json, user_headers } }

    context 'creating a space role' do
      let(:params) do
        {
          type: 'space_auditor',
          relationships: {
            user: {
              data: { guid: user_with_role.guid }
            },
            space: {
              data: { guid: space.guid }
            }
          }
        }
      end

      let(:expected_response) do
        {
          guid: UUID_REGEX,
          created_at: iso8601,
          updated_at: iso8601,
          type: 'space_auditor',
          relationships: {
            user: {
              data: { guid: user_with_role.guid }
            },
            space: {
              data: { guid: space.guid }
            },
            organization: {
              data: nil
            }
          },
          links: {
            self: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/roles\/#{UUID_REGEX}) },
            user: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/users\/#{user_with_role.guid}) },
            space: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/spaces\/#{space.guid}) },
          }
        }
      end

      let(:expected_codes_and_responses) do
        # Note: currently, all users except admins are only able to see
        # themselves, so they all get 422. When we expand the visibility
        # of users, some will get 403s and some will get 422s.
        h = Hash.new(code: 422)
        h['admin'] = {
          code: 201,
          response_object: expected_response
        }
        h['global_auditor'] = { code: 403 }
        h['admin_read_only'] = { code: 403 }
        h
      end

      before do
        org.add_user(user_with_role)
      end

      it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS

      context 'when user is invalid' do
        let(:params) do
          {
            type: 'space_auditor',
            relationships: {
              user: {
                data: { guid: 'not-a-real-user' }
              },
              space: {
                data: { guid: space.guid }
              }
            }
          }
        end

        it 'returns a 422 with a helpful message' do
          post '/v3/roles', params.to_json, admin_header
          expect(last_response.status).to eq(422)
          expect(last_response).to have_error_message('Invalid user. Ensure that the user exists and you have access to it.')
        end
      end

      context 'when space is invalid' do
        let(:params) do
          {
            type: 'space_auditor',
            relationships: {
              user: {
                data: { guid: user_with_role.guid }
              },
              space: {
                data: { guid: 'not-a-real-space' }
              }
            }
          }
        end

        it 'returns a 422 with a helpful message' do
          post '/v3/roles', params.to_json, admin_header
          expect(last_response.status).to eq(422)
          expect(last_response).to have_error_message('Invalid space. Ensure that the space exists and you have access to it.')
        end
      end

      context 'when role already exists' do
        let(:uaa_client) { double(:uaa_client) }

        before do
          allow(CloudController::DependencyLocator.instance).to receive(:uaa_client).and_return(uaa_client)
          allow(uaa_client).to receive(:users_for_ids).with([user_with_role.guid]).and_return(
            { user_with_role.guid => { 'username' => 'mona', 'origin' => 'uaa' } }
          )

          org.add_user(user_with_role)
          post '/v3/roles', params.to_json, admin_header
        end

        it 'returns a 422 with a helpful message' do
          post '/v3/roles', params.to_json, admin_header

          expect(last_response.status).to eq(422)
          expect(last_response).to have_error_message(
            "User 'mona' already has 'space_auditor' role in space '#{space.name}'."
          )
        end
      end
    end

    context 'creating a organization role' do
      let(:params) do
        {
          type: 'organization_auditor',
          relationships: {
            user: {
              data: { guid: user_with_role.guid }
            },
            organization: {
              data: { guid: org.guid }
            }
          }
        }
      end

      let(:expected_response) do
        {
          guid: UUID_REGEX,
          created_at: iso8601,
          updated_at: iso8601,
          type: 'organization_auditor',
          relationships: {
            user: {
              data: { guid: user_with_role.guid }
            },
            space: {
              data: nil
            },
            organization: {
              data: { guid: org.guid }
            }
          },
          links: {
            self: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/roles\/#{UUID_REGEX}) },
            user: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/users\/#{user_with_role.guid}) },
            organization: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/organizations\/#{org.guid}) },
          }
        }
      end

      let(:expected_codes_and_responses) do
        h = Hash.new(code: 422)
        h['admin'] = {
          code: 201,
          response_object: expected_response
        }
        h['admin_read_only'] = {
          code: 403,
        }
        h['global_auditor'] = {
          code: 403,
        }
        h
      end

      it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS

      context 'when user is invalid' do
        let(:params) do
          {
            type: 'organization_auditor',
            relationships: {
              user: {
                data: { guid: 'not-a-real-user' }
              },
              organization: {
                data: { guid: org.guid }
              }
            }
          }
        end

        it 'returns a 422 with a helpful message' do
          post '/v3/roles', params.to_json, admin_header
          expect(last_response.status).to eq(422)
          expect(last_response).to have_error_message('Invalid user. Ensure that the user exists and you have access to it.')
        end
      end

      context 'when organization is invalid' do
        let(:params) do
          {
            type: 'organization_auditor',
            relationships: {
              user: {
                data: { guid: user_with_role.guid }
              },
              organization: {
                data: { guid: 'not-a-real-organization' }
              }
            }
          }
        end

        it 'returns a 422 with a helpful message' do
          post '/v3/roles', params.to_json, admin_header
          expect(last_response.status).to eq(422)
          expect(last_response).to have_error_message('Invalid organization. Ensure that the organization exists and you have access to it.')
        end
      end

      context 'when role already exists' do
        let(:uaa_client) { double(:uaa_client) }

        before do
          allow(CloudController::DependencyLocator.instance).to receive(:uaa_client).and_return(uaa_client)
          allow(uaa_client).to receive(:users_for_ids).with([user_with_role.guid]).and_return(
            { user_with_role.guid => { 'username' => 'mona', 'origin' => 'uaa' } }
          )

          post '/v3/roles', params.to_json, admin_header
        end

        it 'returns a 422 with a helpful message' do
          post '/v3/roles', params.to_json, admin_header

          expect(last_response.status).to eq(422)
          expect(last_response).to have_error_message(
            "User 'mona' already has 'organization_auditor' role in organization '#{org.name}'."
          )
        end
      end
    end
  end
end
