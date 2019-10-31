require 'spec_helper'
require 'request_spec_shared_examples'

RSpec.describe 'Roles Request' do
  let(:user) { VCAP::CloudController::User.make(guid: 'user_guid') }
  let(:admin_header) { admin_headers_for(user) }
  let(:org) { VCAP::CloudController::Organization.make(guid: 'big-org') }
  let(:space) { VCAP::CloudController::Space.make(guid: 'big-space', organization: org) }
  let(:user_with_role) { VCAP::CloudController::User.make(guid: 'user_with_role') }
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
        h = Hash.new(code: 403)
        h['admin'] = {
          code: 201,
          response_object: expected_response
        }
        h['space_manager'] = {
          code: 201,
          response_object: expected_response
        }
        h['org_manager'] = {
          code: 201,
          response_object: expected_response
        }
        h['org_auditor'] = { code: 422 }
        h['org_billing_manager'] = { code: 422 }
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
        h = Hash.new(code: 403)
        h['admin'] = {
          code: 201,
          response_object: expected_response
        }
        h['org_manager'] = {
          code: 201,
          response_object: expected_response
        }
        h
      end

      before do
        org.add_user(user_with_role)
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

    context 'creating a role by username' do
      let(:params) do
        {
          type: 'space_auditor',
          relationships: {
            user: {
              data: {
                name: 'uuu'
              }
            },
            space: {
              data: { guid: space.guid }
            }
          }
        }
      end

      let(:uaa_client) { double(:uaa_client) }

      context 'when the user exists in a single origin' do
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
          h = Hash.new(code: 403)
          h['admin'] = {
            code: 201,
            response_object: expected_response
          }
          h['space_manager'] = {
            code: 201,
            response_object: expected_response
          }
          h['org_manager'] = {
            code: 201,
            response_object: expected_response
          }
          h['org_auditor'] = { code: 422 }
          h['org_billing_manager'] = { code: 422 }
          h
        end

        before do
          allow(CloudController::DependencyLocator.instance).to receive(:uaa_client).and_return(uaa_client)
          allow(uaa_client).to receive(:origins_for_username).with('uuu').and_return(['uaa'])
          allow(uaa_client).to receive(:id_for_username).with('uuu', origin: 'uaa').and_return(user_with_role.guid)

          org.add_user(user_with_role)
        end

        it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS
      end

      context 'when there are multiple users with the same username' do
        before do
          allow(CloudController::DependencyLocator.instance).to receive(:uaa_client).and_return(uaa_client)
          allow(uaa_client).to receive(:origins_for_username).with('uuu').and_return(%w(uaa ldap okta))
          allow(uaa_client).to receive(:id_for_username).with('uuu', origin: 'uaa').and_return(user_with_role.guid)
        end

        it 'returns a 422 with a helpful message' do
          post '/v3/roles', params.to_json, admin_header

          expect(last_response.status).to eq(422)
          expect(last_response).to have_error_message(
            "User with username 'uuu' exists in the following origins: uaa, ldap, okta. Specify an origin to disambiguate."
          )
        end
      end

      context 'when there is no user with the given username' do
        before do
          allow(CloudController::DependencyLocator.instance).to receive(:uaa_client).and_return(uaa_client)
          allow(uaa_client).to receive(:origins_for_username).with('uuu').and_return([])
          allow(uaa_client).to receive(:id_for_username).with('uuu', origin: nil).and_return(nil)
        end

        it 'returns a 422 with a helpful message' do
          post '/v3/roles', params.to_json, admin_header

          expect(last_response.status).to eq(422)
          expect(last_response).to have_error_message(
            "No user exists with the username 'uuu'."
          )
        end
      end
    end

    context 'creating a role by username and origin' do
      let(:params) do
        {
          type: 'space_auditor',
          relationships: {
            user: {
              data: {
                name: 'uuu',
                origin: 'okta'
              }
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
        h = Hash.new(code: 403)
        h['admin'] = {
          code: 201,
          response_object: expected_response
        }
        h['space_manager'] = {
          code: 201,
          response_object: expected_response
        }
        h['org_manager'] = {
          code: 201,
          response_object: expected_response
        }
        h['org_auditor'] = { code: 422 }
        h['org_billing_manager'] = { code: 422 }
        h
      end

      let(:uaa_client) { double(:uaa_client) }

      before do
        allow(CloudController::DependencyLocator.instance).to receive(:uaa_client).and_return(uaa_client)
        allow(uaa_client).to receive(:id_for_username).with('uuu', origin: 'okta').and_return(user_with_role.guid)

        org.add_user(user_with_role)
      end

      it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS

      context 'when there is no user with the given username and origin' do
        before do
          allow(CloudController::DependencyLocator.instance).to receive(:uaa_client).and_return(uaa_client)
          allow(uaa_client).to receive(:origins_for_username).with('uuu').and_return(['something-else'])
          allow(uaa_client).to receive(:id_for_username).with('uuu', origin: 'okta').and_return(nil)
        end

        it 'returns a 422 with a helpful message' do
          post '/v3/roles', params.to_json, admin_header

          expect(last_response.status).to eq(422)
          expect(last_response).to have_error_message(
            "No user exists with the username 'uuu' and origin 'okta'."
          )
        end
      end
    end
  end

  describe 'GET /v3/roles' do
    let(:api_call) { lambda { |user_headers| get '/v3/roles', nil, user_headers } }
    let(:other_user) { VCAP::CloudController::User.make }

    let!(:space_auditor) do
      VCAP::CloudController::SpaceAuditor.make(guid: 'space-role-guid', space: space, user: other_user, created_at: Time.now - 5.minutes)
    end
    let!(:organization_auditor) do
      VCAP::CloudController::OrganizationAuditor.make(guid: 'organization-role-guid', organization: org, user: other_user, created_at: Time.now)
    end

    let(:space_response_object) do
      {
        guid: space_auditor.guid,
        created_at: iso8601,
        updated_at: iso8601,
        type: 'space_auditor',
        relationships: {
          user: {
            data: { guid: other_user.guid }
          },
          organization: {
            data: nil
          },
          space: {
            data: { guid: space.guid }
          }
        },
        links: {
          self: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/roles\/#{UUID_REGEX}) },
          user: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/users\/#{other_user.guid}) },
          space: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/spaces\/#{space.guid}) },
        }
      }
    end

    let(:org_response_object) do
      {
        guid: organization_auditor.guid,
        created_at: iso8601,
        updated_at: iso8601,
        type: 'organization_auditor',
        relationships: {
          user: {
            data: { guid: other_user.guid }
          },
          organization: {
            data: { guid: org.guid }
          },
          space: {
            data: nil
          }
        },
        links: {
          self: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/roles\/#{UUID_REGEX}) },
          user: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/users\/#{other_user.guid}) },
          organization: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/organizations\/#{org.guid}) },
        }
      }
    end

    def make_org_role_for_current_user(type)
      {
        guid: UUID_REGEX,
        created_at: iso8601,
        updated_at: iso8601,
        type: type,
        relationships: {
          user: {
            data: { guid: user.guid }
          },
          organization: {
            data: { guid: org.guid }
          },
          space: {
            data: nil
          }
        },
        links: {
          self: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/roles\/#{UUID_REGEX}) },
          user: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/users\/#{user.guid}) },
          organization: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/organizations\/#{org.guid}) },
        }
      }
    end

    def make_space_role_for_current_user(type)
      {
        guid: UUID_REGEX,
        created_at: iso8601,
        updated_at: iso8601,
        type: type,
        relationships: {
          user: {
            data: { guid: user.guid }
          },
          organization: {
            data: nil
          },
          space: {
            data: { guid: space.guid }
          }
        },
        links: {
          self: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/roles\/#{UUID_REGEX}) },
          user: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/users\/#{user.guid}) },
          space: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/spaces\/#{space.guid}) },
        }
      }
    end

    context 'listing all roles' do
      let(:expected_codes_and_responses) do
        h = Hash.new(code: 200, response_objects: [space_response_object, org_response_object])

        h['org_auditor'] = {
          code: 200,
          response_objects: contain_exactly(
            org_response_object,
            # TODO: update to include space response object after
            make_org_role_for_current_user('organization_user'),
            make_org_role_for_current_user('organization_auditor')
          )
        }

        h['org_manager'] = {
          code: 200,
          response_objects: contain_exactly(
            space_response_object,
            org_response_object,
            make_org_role_for_current_user('organization_user'),
            make_org_role_for_current_user('organization_manager')
          )
        }

        h['org_billing_manager'] = {
          code: 200,
          response_objects: contain_exactly(
            org_response_object,
            # TODO: update to include space response object after
            make_org_role_for_current_user('organization_user'),
            make_org_role_for_current_user('organization_billing_manager')
          )
        }

        h['space_manager'] = {
          code: 200,
          response_objects: contain_exactly(
            space_response_object,
            org_response_object,
            make_org_role_for_current_user('organization_user'),
            make_space_role_for_current_user('space_manager')
          )
        }

        h['space_auditor'] = {
          code: 200,
          response_objects: contain_exactly(
            space_response_object,
            org_response_object,
            make_org_role_for_current_user('organization_user'),
            make_space_role_for_current_user('space_auditor')
          )
        }

        h['space_developer'] = {
          code: 200,
          response_objects: contain_exactly(
            space_response_object,
            org_response_object,
            make_org_role_for_current_user('organization_user'),
            make_space_role_for_current_user('space_developer')
          )
        }

        h['no_role'] = { code: 200, response_objects: [] }
        h
      end

      it_behaves_like 'permissions for list endpoint', ALL_PERMISSIONS

      context 'when the user is not logged in' do
        it 'returns 401 for Unauthenticated requests' do
          post '/v3/roles', nil, base_json_headers
          expect(last_response.status).to eq(401)
        end
      end
    end
  end
end
