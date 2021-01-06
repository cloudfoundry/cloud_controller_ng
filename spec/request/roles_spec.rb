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
  let(:user_unaffiliated) { VCAP::CloudController::User.make(guid: 'user_no_role') }
  let(:uaa_client) { instance_double(VCAP::CloudController::UaaClient) }

  before do
    allow(CloudController::DependencyLocator.instance).to receive(:uaa_client).and_return(uaa_client)
    allow(uaa_client).to receive(:usernames_for_ids).with([user_with_role.guid]).and_return(
      { user_with_role.guid => 'mona' }
    )
    allow(uaa_client).to receive(:usernames_for_ids).with([user_unaffiliated.guid]).and_return(
      { user_with_role.guid => 'bob_unaffiliated' }
    )
  end

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
          expect(last_response).to have_status_code(422)
          expect(last_response).to have_error_message("Users cannot be assigned roles in a space if they do not have a role in that space's organization.")
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
          expect(last_response).to have_status_code(422)
          expect(last_response).to have_error_message('Invalid space. Ensure that the space exists and you have access to it.')
        end
      end

      context 'when role already exists' do
        before do
          org.add_user(user_with_role)
          post '/v3/roles', params.to_json, admin_header
        end

        it 'returns a 422 with a helpful message' do
          post '/v3/roles', params.to_json, admin_header

          expect(last_response).to have_status_code(422)
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
          expect(last_response).to have_status_code(422)
          expect(last_response).to have_error_message('Invalid organization. Ensure that the organization exists and you have access to it.')
        end
      end

      context 'when role already exists' do
        before do
          post '/v3/roles', params.to_json, admin_header
        end

        it 'returns a 422 with a helpful message' do
          post '/v3/roles', params.to_json, admin_header

          expect(last_response).to have_status_code(422)
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
                username: 'uuu'
              }
            },
            space: {
              data: { guid: space.guid }
            }
          }
        }
      end

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
          allow(uaa_client).to receive(:origins_for_username).with('uuu').and_return(['uaa'])
          allow(uaa_client).to receive(:id_for_username).with('uuu', origin: 'uaa').and_return(user_with_role.guid)
          org.add_user(user_with_role)
        end

        it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS
      end

      context 'when there are multiple users with the same username' do
        before do
          allow(uaa_client).to receive(:origins_for_username).with('uuu').and_return(%w(uaa ldap okta))
          allow(uaa_client).to receive(:id_for_username).with('uuu', origin: 'uaa').and_return(user_with_role.guid)
        end

        it 'returns a 422 with a helpful message' do
          post '/v3/roles', params.to_json, admin_header

          expect(last_response).to have_status_code(422)
          expect(last_response).to have_error_message(
            "User with username 'uuu' exists in the following origins: ldap, okta, uaa. Specify an origin to disambiguate."
          )
        end
      end

      context 'when there is no user with the given username' do
        before do
          allow(uaa_client).to receive(:origins_for_username).with('uuu').and_return([])
          allow(uaa_client).to receive(:id_for_username).with('uuu', origin: nil).and_return(nil)
        end

        context 'for a space role' do
          it 'returns a 422 with a helpful message' do
            post '/v3/roles', params.to_json, admin_header

            expect(last_response).to have_status_code(422)
            expect(last_response).to have_error_message(
              "Users cannot be assigned roles in a space if they do not have a role in that space's organization."
            )
          end
        end

        context 'for an org role' do
          let(:params) do
            {
              type: 'organization_auditor',
              relationships: {
                user: {
                  data: {
                    username: 'uuu'
                  }
                },
                organization: {
                  data: { guid: org.guid }
                }
              }
            }
          end

          it 'returns a 422 with a helpful message' do
            post '/v3/roles', params.to_json, admin_header

            expect(last_response).to have_status_code(422)
            expect(last_response).to have_error_message(
              "No user exists with the username 'uuu'."
            )
          end
        end
      end
    end

    context 'creating role by user GUID for unaffiliated user' do
      let(:params) do
        {
          type: 'organization_auditor',
          relationships: {
            user: {
              data: { guid: user_unaffiliated.guid }
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
              data: { guid: user_unaffiliated.guid }
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
            user: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/users\/#{user_unaffiliated.guid}) },
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
          code: 422
        }
        h
      end

      before do
        allow(uaa_client).to receive(:users_for_ids).with([user_unaffiliated.guid]).and_return({ user_unaffiliated.guid => { 'username' => user_unaffiliated.username } })
        allow(uaa_client).to receive(:usernames_for_ids).with([user_unaffiliated.guid]).and_return({ user_unaffiliated.guid => 'bob_unaffiliated' })
      end

      it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS
    end

    context 'creating a role by username and origin' do
      let(:params) do
        {
          type: 'space_auditor',
          relationships: {
            user: {
              data: {
                username: 'uuu',
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

      before do
        allow(uaa_client).to receive(:id_for_username).with('uuu', origin: 'okta').and_return(user_with_role.guid)

        org.add_user(user_with_role)
      end

      it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS

      context 'when the flag to set roles by username is disabled' do
        before do
          VCAP::CloudController::FeatureFlag.make(name: 'set_roles_by_username')
        end

        let(:params) do
          {
            type: 'space_auditor',
            relationships: {
              user: {
                data: {
                  username: 'uuu',
                  origin: 'okta'
                }
              },
              space: {
                data: { guid: space.guid }
              }
            }
          }
        end

        let(:expected_codes_and_responses) do
          h = Hash.new(code: 403)
          h['admin'] = {
            code: 201,
            response_object: expected_response
          }

          h['org_auditor'] = { code: 422 }
          h['org_billing_manager'] = { code: 422 }
          h
        end
        it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS
      end

      context 'when there is no user with the given username and origin' do
        before do
          allow(uaa_client).to receive(:origins_for_username).with('uuu').and_return(['something-else'])
          allow(uaa_client).to receive(:id_for_username).with('uuu', origin: 'okta').and_return(nil)
        end

        context 'for a space role' do
          it 'returns a 422 with a helpful message' do
            post '/v3/roles', params.to_json, admin_header

            expect(last_response).to have_status_code(422)
            expect(last_response).to have_error_message(
              "Users cannot be assigned roles in a space if they do not have a role in that space's organization."
            )
          end
        end

        context 'for an org role' do
          let(:params) do
            {
              type: 'organization_auditor',
              relationships: {
                user: {
                  data: {
                    username: 'uuu',
                    origin: 'okta'
                  }
                },
                organization: {
                  data: { guid: org.guid }
                }
              }
            }
          end

          it 'returns a 422 with a helpful message' do
            post '/v3/roles', params.to_json, admin_header

            expect(last_response).to have_status_code(422)
            expect(last_response).to have_error_message(
              "No user exists with the username 'uuu' and origin 'okta'."
            )
          end
        end
      end

      context 'when UAA is unavailable' do
        before do
          allow(uaa_client).to receive(:id_for_username).and_raise(VCAP::CloudController::UaaUnavailable)
        end

        it 'raises a 502 with a helpful message' do
          post '/v3/roles', params.to_json, admin_header

          expect(last_response).to have_status_code(503)
          expect(last_response).to have_error_message(
            'UAA service is currently unavailable'
          )
        end
      end

      # This case only applies for creating org roles, any user that would be able to have
      # a space role must also have at least an org user role
      context 'when the user is unaffiliated' do
        before do
          allow(uaa_client).to receive(:origins_for_username).with('bob_unaffiliated').and_return(['uaa'])
          allow(uaa_client).to receive(:id_for_username).with('bob_unaffiliated', origin: 'uaa').and_return(user_unaffiliated.guid)
          allow(uaa_client).to receive(:usernames_for_ids).with([user_unaffiliated.guid]).and_return({ user_unaffiliated.guid => 'bob_unaffiliated' })
        end

        let(:params) do
          {
            type: 'organization_auditor',
            relationships: {
              user: {
                data: {
                  username: 'bob_unaffiliated'
                }
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
                data: { guid: user_unaffiliated.guid }
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
              user: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/users\/#{user_unaffiliated.guid}) },
              organization: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/organizations\/#{org.guid}) },
            }
          }
        end

        let(:expected_codes_and_responses) do
          h = Hash.new(
            code: 403,
          )
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

        it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS

        context 'when the flag to set roles by username is disabled' do
          before do
            VCAP::CloudController::FeatureFlag.make(name: 'set_roles_by_username')
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
        end
      end
    end

    context 'creating a role for a user that does not exist' do
      let(:expected_response) do
        {
          guid: UUID_REGEX,
          created_at: iso8601,
          updated_at: iso8601,
          type: 'organization_auditor',
          relationships: {
            user: {
              data: { guid: 'a-new-user-guid' }
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
            user: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/users\/a-new-user-guid) },
            organization: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/organizations\/#{org.guid}) },
          }
        }
      end

      before do
        allow(uaa_client).to receive(:usernames_for_ids).with(['a-new-user-guid']).and_return({ 'a-new-user-guid' => 'a-new-user-name' })
        allow(uaa_client).to receive(:id_for_username).with('a-new-user-name', origin: 'uaa').and_return('a-new-user-guid')
        allow(uaa_client).to receive(:users_for_ids).with(['a-new-user-guid']).and_return({ 'a-new-user-guid' => { 'username' => 'a-new-user-name' } })
      end

      context 'by user guid' do
        let(:params) do
          {
            type: 'organization_auditor',
            relationships: {
              user: {
                data: { guid: 'a-new-user-guid' }
              },
              organization: {
                data: { guid: org.guid }
              }
            }
          }
        end

        it 'creates the user and the role' do
          expect(VCAP::CloudController::User.where(guid: 'a-new-user-guid').empty?).to be true
          post '/v3/roles', params.to_json, admin_headers

          expect(last_response).to have_status_code(201)
          expect(parsed_response).to match_json_response(expected_response)
          expect(VCAP::CloudController::User.where(guid: 'a-new-user-guid').empty?).to be false
        end
      end

      context 'by user name' do
        let(:params) do
          {
            type: 'organization_auditor',
            relationships: {
              user: {
                data: { username: 'a-new-user-name', origin: 'uaa' }
              },
              organization: {
                data: { guid: org.guid }
              }
            }
          }
        end

        it 'creates the user and the role' do
          expect(VCAP::CloudController::User.where(guid: 'a-new-user-guid').empty?).to be true
          post '/v3/roles', params.to_json, admin_headers

          expect(last_response).to have_status_code(201)
          expect(parsed_response).to match_json_response(expected_response)
          expect(VCAP::CloudController::User.where(guid: 'a-new-user-guid').empty?).to be false
        end
      end

      context 'when the request is for a space role' do
        let(:params) do
          {
            type: 'space_auditor',
            relationships: {
              user: {
                data: { guid: 'a-new-user-guid' }
              },
              space: {
                data: { guid: space.guid }
              }
            }
          }
        end

        it 'raises the same error as a user that does not exist at all, without creating a new user' do
          expect(VCAP::CloudController::User.where(guid: 'a-new-user-guid').empty?).to be true
          post '/v3/roles', params.to_json, admin_headers

          expect(last_response).to have_status_code(422)
          expect(last_response).to have_error_message("Users cannot be assigned roles in a space if they do not have a role in that space's organization.")
          expect(VCAP::CloudController::User.where(guid: 'a-new-user-guid').empty?).to be true
        end
      end
    end
  end

  describe 'GET /v3/roles' do
    let(:api_call) { lambda { |user_headers| get '/v3/roles', nil, user_headers } }
    let(:other_user) { VCAP::CloudController::User.make(guid: 'other-user-guid') }

    let!(:space_auditor) do
      VCAP::CloudController::SpaceAuditor.make(
        guid: 'space-role-guid',
        space: space,
        user: other_user,
        created_at: Time.now - 5.minutes,
      )
    end

    let!(:organization_auditor) do
      VCAP::CloudController::OrganizationAuditor.make(
        guid: 'organization-role-guid',
        organization: org,
        user: other_user,
        created_at: Time.now,
      )
    end

    let(:space_auditor_response_object) do
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

    let(:org_auditor_response_object) do
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

    describe 'list query parameters' do
      before do
        allow(uaa_client).to receive(:users_for_ids).and_return([])
      end

      it_behaves_like 'list query endpoint' do
        let(:request) { 'v3/roles' }
        let(:message) { VCAP::CloudController::RolesListMessage }
        let(:user_header) { headers_for(user) }
        let(:params) do
          {
            guids: ['foo', 'bar'],
            organization_guids: ['foo', 'bar'],
            space_guids: ['foo', 'bar'],
            user_guids: ['foo', 'bar'],
            types: ['foo', 'bar'],
            per_page: '10',
            page: 2,
            order_by: 'updated_at',
            include: 'user, space',
            created_ats:  "#{Time.now.utc.iso8601},#{Time.now.utc.iso8601}",
            updated_ats: { gt: Time.now.utc.iso8601 },
          }
        end
      end
    end

    describe 'eager loading' do
      it 'eager loads associated resources that the presenter specifies' do
        expect(VCAP::CloudController::RoleListFetcher).to receive(:fetch).with(
          anything,
          anything,
          hash_including(eager_loaded_associations: [:user, :space, :organization])
        ).and_call_original

        get '/v3/roles', nil, admin_header
        expect(last_response).to have_status_code(200)
      end
    end

    context 'listing all roles' do
      let(:expected_codes_and_responses) do
        h = Hash.new(code: 200, response_objects: [space_auditor_response_object, org_auditor_response_object])

        h['org_auditor'] = {
          code: 200,
          response_objects: contain_exactly(
            org_auditor_response_object,
            make_org_role_for_current_user('organization_user'),
            make_org_role_for_current_user('organization_auditor')
          )
        }

        h['org_manager'] = {
          code: 200,
          response_objects: contain_exactly(
            space_auditor_response_object,
            org_auditor_response_object,
            make_org_role_for_current_user('organization_user'),
            make_org_role_for_current_user('organization_manager')
          )
        }

        h['org_billing_manager'] = {
          code: 200,
          response_objects: contain_exactly(
            org_auditor_response_object,
            make_org_role_for_current_user('organization_user'),
            make_org_role_for_current_user('organization_billing_manager')
          )
        }

        h['space_manager'] = {
          code: 200,
          response_objects: contain_exactly(
            space_auditor_response_object,
            org_auditor_response_object,
            make_org_role_for_current_user('organization_user'),
            make_space_role_for_current_user('space_manager')
          )
        }

        h['space_auditor'] = {
          code: 200,
          response_objects: contain_exactly(
            space_auditor_response_object,
            org_auditor_response_object,
            make_org_role_for_current_user('organization_user'),
            make_space_role_for_current_user('space_auditor')
          )
        }

        h['space_developer'] = {
          code: 200,
          response_objects: contain_exactly(
            space_auditor_response_object,
            org_auditor_response_object,
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
          expect(last_response).to have_status_code(401)
        end
      end
    end

    context 'listing roles with filters' do
      let(:too_late_org_role) { OrganizationAuditor.make(user: other_user, organization: org, created_at: '2028-05-26T18:47:01Z') }
      let(:api_call) { lambda { |user_headers|
                         get "/v3/roles?user_guids=#{other_user.guid}&
order_by=-created_at&created_ats[lt]=2028-05-26T18:47:01Z&guids=#{organization_auditor.guid},#{space_auditor.guid}",
                                                 nil,
                                                 user_headers
                       }
      }

      let(:expected_codes_and_responses) do
        h = Hash.new(code: 200, response_objects: [org_auditor_response_object, space_auditor_response_object])
        h['org_auditor'] = {
          code: 200,
          response_objects: contain_exactly(
            org_auditor_response_object,
          )
        }
        h['org_billing_manager'] = {
          code: 200,
          response_objects: contain_exactly(
            org_auditor_response_object,
          )
        }
        h['no_role'] = { code: 200, response_objects: [] }
        h
      end

      it_behaves_like 'permissions for list endpoint', ALL_PERMISSIONS
    end

    context 'listing roles with include' do
      let(:other_user_response) do
        {
          guid: other_user.guid,
          created_at: iso8601,
          updated_at: iso8601,
          username: 'other_user_name',
          presentation_name: 'other_user_name',
          origin: 'uaa',
          metadata: {
            labels: {},
            annotations: {},
          },
          links: {
            self: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/users\/#{other_user.guid}) },
          }
        }
      end

      let(:org_response_object) do
        {
          guid: org.guid,
          created_at: iso8601,
          updated_at: iso8601,
          name: org.name,
          suspended: false,
          relationships: {
            quota: {
              data: { guid: org.quota_definition.guid }
            }
          },
          metadata: {
            labels: {},
            annotations: {},
          },
          links: {
            self: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/organizations\/#{org.guid}) },
            domains: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/organizations\/#{org.guid}\/domains) },
            default_domain: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/organizations\/#{org.guid}\/domains/default) },
            quota: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/organization_quotas\/#{org.quota_definition.guid}) }
          }
        }
      end

      let(:space_response_object) do
        {
          guid: space.guid,
          created_at: iso8601,
          updated_at: iso8601,
          name: space.name,
          relationships: {
            organization: {
              data: { guid: org.guid }
            },
            quota: {
              data: nil
            }
          },
          metadata: {
            labels: {},
            annotations: {},
          },
          links: {
            self: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/spaces\/#{space.guid}) },
            organization: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/organizations\/#{org.guid}) },
            features: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/spaces\/#{space.guid}/features) },
            apply_manifest: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/spaces\/#{space.guid}/actions/apply_manifest), method: 'POST' }
          }
        }
      end

      before do
        allow(uaa_client).to receive(:users_for_ids).with([other_user.guid]).and_return(
          { other_user.guid => { 'username' => 'other_user_name', 'origin' => 'uaa' } }
        )
      end

      it 'includes the requested users' do
        get('/v3/roles?include=user,organization,space', nil, admin_header)
        expect(last_response).to have_status_code(200)

        parsed_response = MultiJson.load(last_response.body)
        expect(parsed_response['included']['users'][0]).to match_json_response(other_user_response)
        expect(parsed_response['included']['organizations'][0]).to match_json_response(org_response_object)
        expect(parsed_response['included']['spaces'][0]).to match_json_response(space_response_object)
      end

      context 'when there are multiple users with multiple roles' do
        let(:another_user) { VCAP::CloudController::User.make(guid: 'another-user-guid') }
        let(:another_org) { VCAP::CloudController::Organization.make }
        let(:another_space) { VCAP::CloudController::Space.make }

        let(:another_user_response) do
          {
            guid: another_user.guid,
            created_at: iso8601,
            updated_at: iso8601,
            username: 'another_user_name',
            presentation_name: 'another_user_name', # username is nil, so presenter defaults to guid
            origin: 'uaa',
            metadata: {
              labels: {},
              annotations: {},
            },
            links: {
              self: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/users\/#{another_user.guid}) },
            }
          }
        end

        let(:another_space_response) do
          {
            guid: another_space.guid,
            created_at: iso8601,
            updated_at: iso8601,
            name: another_space.name,
            relationships: {
              organization: {
                data: { guid: another_space.organization.guid }
              },
              quota: {
                data: nil
              }
            },
            metadata: {
              labels: {},
              annotations: {},
            },
            links: {
              self: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/spaces\/#{another_space.guid}) },
              organization: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/organizations\/#{another_space.organization.guid}) },
              features: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/spaces\/#{another_space.guid}\/features) },
              apply_manifest: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/spaces\/#{another_space.guid}/actions/apply_manifest), method: 'POST' }
            }
          }
        end

        let(:another_org_response) do
          {
            guid: another_org.guid,
            created_at: iso8601,
            updated_at: iso8601,
            name: another_org.name,
            suspended: false,
            relationships: {
              quota: {
                data: { guid: another_org.quota_definition.guid }
              }
            },
            metadata: {
              labels: {},
              annotations: {},
            },
            links: {
              self: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/organizations\/#{another_org.guid}) },
              domains: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/organizations\/#{another_org.guid}\/domains) },
              default_domain: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/organizations\/#{another_org.guid}\/domains/default) },
              quota: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/organization_quotas\/#{another_org.quota_definition.guid}) }
            }
          }
        end

        let!(:organization_billing_manager) do
          VCAP::CloudController::OrganizationBillingManager.make(
            guid: 'organization_billing_manager-guid',
            organization: org,
            user: another_user,
            created_at: Time.now - 3.minutes,
          )
        end

        let!(:space_auditor) do
          VCAP::CloudController::SpaceAuditor.make(
            guid: 'space_auditor-guid',
            space: space,
            user: another_user
          )
        end

        let!(:another_space_auditor) do
          VCAP::CloudController::SpaceAuditor.make(
            guid: 'another-space_auditor-guid',
            space: another_space,
            user: another_user
          )
        end

        let!(:org_manager) do
          VCAP::CloudController::OrganizationManager.make(
            guid: 'organization_manager-guid',
            organization: another_org,
            user: another_user
          )
        end

        before do
          allow(uaa_client).to receive(:users_for_ids).with(contain_exactly(other_user.guid, another_user.guid)).and_return(
            {
              another_user.guid => { 'username' => 'another_user_name', 'origin' => 'uaa' },
              other_user.guid => { 'username' => 'other_user_name', 'origin' => 'uaa' }
            }
          )
        end

        it 'returns all of the relevant users' do
          get('/v3/roles?include=user,space,organization', nil, admin_header)
          expect(last_response).to have_status_code(200)

          parsed_response = MultiJson.load(last_response.body)
          expect(parsed_response['included']['users']).to contain_exactly(
            match_json_response(other_user_response),
            match_json_response(another_user_response)
          )
          expect(parsed_response['included']['spaces']).to contain_exactly(
            match_json_response(space_response_object),
            match_json_response(another_space_response)
          )
          expect(parsed_response['included']['organizations']).to contain_exactly(
            match_json_response(org_response_object),
            match_json_response(another_org_response)
          )
        end
      end
    end
  end

  describe 'GET /v3/roles/:guid' do
    let(:api_call) { lambda { |user_headers| get "/v3/roles/#{role.guid}", nil, user_headers } }

    context 'when getting a space role' do
      let(:role) { VCAP::CloudController::SpaceAuditor.make(user: user_with_role, space: space) }

      let(:expected_response) do
        {
          guid: role.guid,
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
            self: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/roles\/#{role.guid}) },
            user: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/users\/#{user_with_role.guid}) },
            space: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/spaces\/#{space.guid}) },
          }
        }
      end

      let(:expected_codes_and_responses) do
        responses_for_space_restricted_single_endpoint(expected_response)
      end

      before do
        org.add_user(user_with_role)
      end

      it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS
    end

    context 'when getting a org role' do
      let(:role) { VCAP::CloudController::OrganizationAuditor.make(user: user_with_role, organization: org) }

      let(:expected_response) do
        {
          guid: role.guid,
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
            self: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/roles\/#{role.guid}) },
            user: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/users\/#{user_with_role.guid}) },
            organization: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/organizations\/#{org.guid}) },
          }
        }
      end

      let(:expected_codes_and_responses) do
        h = Hash.new(code: 200, response_object: expected_response)
        h['no_role'] = { code: 404 }
        h
      end

      it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS
    end

    context 'when the role does not exist' do
      it 'returns a 404 with a helpful message' do
        get '/v3/roles/not-exist', nil, admin_header

        expect(last_response).to have_status_code(404)
        expect(last_response).to have_error_message('Role not found')
      end
    end

    context 'when not logged in' do
      it 'returns a 401 with a helpful message' do
        get '/v3/roles/not-exist', nil, {}

        expect(last_response).to have_status_code(401)
        expect(last_response).to have_error_message('Authentication error')
      end
    end

    context 'getting a role with included resources' do
      let(:org_role) { VCAP::CloudController::OrganizationAuditor.make(user: user_with_role, organization: org) }
      let(:space_role) { VCAP::CloudController::SpaceAuditor.make(user: user_with_role, space: space) }

      let(:user_with_role_response) do
        {
          guid: user_with_role.guid,
          created_at: iso8601,
          updated_at: iso8601,
          username: 'user_name',
          presentation_name: 'user_name',
          origin: 'uaa',
          metadata: {
            labels: {},
            annotations: {},
          },
          links: {
            self: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/users\/#{user_with_role.guid}) },
          }
        }
      end

      let(:org_response_object) do
        {
          guid: org.guid,
          created_at: iso8601,
          updated_at: iso8601,
          name: org.name,
          suspended: false,
          relationships: {
            quota: {
              data: { guid: org.quota_definition.guid }
            }
          },
          metadata: {
            labels: {},
            annotations: {},
          },
          links: {
            self: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/organizations\/#{org.guid}) },
            domains: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/organizations\/#{org.guid}\/domains) },
            default_domain: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/organizations\/#{org.guid}\/domains/default) },
            quota: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/organization_quotas\/#{org.quota_definition.guid}) }
          }
        }
      end

      let(:space_response_object) do
        {
          guid: space.guid,
          created_at: iso8601,
          updated_at: iso8601,
          name: space.name,
          relationships: {
            organization: {
              data: { guid: org.guid }
            },
            quota: {
              data: nil
            }
          },
          metadata: {
            labels: {},
            annotations: {},
          },
          links: {
            self: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/spaces\/#{space.guid}) },
            organization: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/organizations\/#{org.guid}) },
            features: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/spaces\/#{space.guid}/features) },
            apply_manifest: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/spaces\/#{space.guid}/actions/apply_manifest), method: 'POST' }
          }
        }
      end

      before do
        allow(uaa_client).to receive(:users_for_ids).with([user_with_role.guid]).and_return(
          { user_with_role.guid => { 'username' => 'user_name', 'origin' => 'uaa' } }
        )
      end

      context 'for an org role' do
        it 'includes the requested users and organization' do
          get("/v3/roles/#{org_role.guid}?include=user,space,organization", nil, admin_header)
          expect(last_response).to have_status_code(200)

          parsed_response = MultiJson.load(last_response.body)
          expect(parsed_response['included']['users'][0]).to match_json_response(user_with_role_response)
          expect(parsed_response['included']['organizations'][0]).to match_json_response(org_response_object)
          expect(parsed_response['included']['spaces']).to eq([])
        end
      end

      context 'for a space role' do
        it 'includes the requested users and organization' do
          get("/v3/roles/#{space_role.guid}?include=user,space,organization", nil, admin_header)
          expect(last_response).to have_status_code(200)

          parsed_response = MultiJson.load(last_response.body)
          expect(parsed_response['included']['users'][0]).to match_json_response(user_with_role_response)
          expect(parsed_response['included']['organizations']).to eq([])
          expect(parsed_response['included']['spaces'][0]).to match_json_response(space_response_object)
        end
      end
    end
  end

  describe 'DELETE /v3/roles/:guid' do
    let(:api_call) { lambda { |headers| delete "/v3/roles/#{role.guid}", nil, headers } }
    let(:db_check) do
      lambda do
        expect(last_response.headers['Location']).to match(%r(http.+/v3/jobs/[a-fA-F0-9-]+))

        job_guid = last_response.headers['Location'].gsub("#{link_prefix}/v3/jobs/", '')
        get "/v3/jobs/#{job_guid}", {}, admin_headers
        expect(last_response).to have_status_code(200)

        execute_all_jobs(expected_successes: 1, expected_failures: 0)
        get "/v3/roles/#{role.guid}", {}, admin_headers
        expect(last_response).to have_status_code(404)
      end
    end

    before do
      org.add_user(user_with_role)
    end

    context 'when deleting a space role' do
      let(:role) { VCAP::CloudController::SpaceAuditor.make(user: user_with_role, space: space) }

      let(:expected_codes_and_responses) do
        h = Hash.new(code: 403)
        h['admin'] = { code: 202 }
        h['space_manager'] = { code: 202 }
        h['org_manager'] = { code: 202 }
        h['org_auditor'] = { code: 404 }
        h['org_billing_manager'] = { code: 404 }
        h['no_role'] = { code: 404 }
        h
      end

      it_behaves_like 'permissions for delete endpoint', ALL_PERMISSIONS
    end

    context 'when deleting an org role' do
      let(:role) { VCAP::CloudController::OrganizationAuditor.make(user: user_with_role, organization: org) }

      let(:expected_codes_and_responses) do
        h = Hash.new(code: 403)
        h['admin'] = { code: 202 }
        h['org_manager'] = { code: 202 }
        h['no_role'] = { code: 404 }
        h
      end

      it_behaves_like 'permissions for delete endpoint', ALL_PERMISSIONS

      context 'and the user still has a role in a space within that org' do
        let(:org_user_role) { VCAP::CloudController::OrganizationUser.find(user_id: user_with_role.id) }

        before do
          space.add_manager(user_with_role)
        end

        it 'should return a 422 when trying to delete the organization_user role' do
          delete "/v3/roles/#{org_user_role.guid}", nil, admin_headers
          expect(last_response).to have_status_code(422)
        end

        it 'should successfully delete any other org role' do
          delete "/v3/roles/#{role.guid}", nil, admin_headers
          expect(last_response).to have_status_code(202)
        end
      end
    end

    context 'when the user is not logged in' do
      let(:role) { VCAP::CloudController::SpaceAuditor.make(user: user_with_role, space: space) }

      it 'returns a 401' do
        delete "/v3/roles/#{role.guid}", nil, base_json_headers
        expect(last_response).to have_status_code(401)
      end
    end

    context 'when the requested role does not exist' do
      let(:headers) { headers_for(user, scopes: %w(cloud_controller.write)) }

      before do
        set_current_user_as_role(role: 'org_manager', org: org, space: space, user: user)
      end

      it 'returns a 404 not found' do
        delete('/v3/roles/does-not-exist', nil, headers)
        expect(last_response).to have_status_code(404)
      end
    end
  end
end
