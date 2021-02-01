require 'spec_helper'
require 'request_spec_shared_examples'

module VCAP::CloudController
  RSpec.describe 'space_quotas' do
    let(:user) { VCAP::CloudController::User.make(guid: 'user-guid') }
    let(:org) { VCAP::CloudController::Organization.make(guid: 'organization-guid') }
    let!(:space_quota) { VCAP::CloudController::SpaceQuotaDefinition.make(guid: 'space-quota-guid', organization: org) }
    let(:space) { VCAP::CloudController::Space.make(guid: 'space-guid', organization: org, space_quota_definition: space_quota) }
    let(:admin_header) { headers_for(user, scopes: %w(cloud_controller.admin)) }

    describe 'GET /v3/space_quotas/:guid' do
      let(:api_call) { lambda { |user_headers| get "/v3/space_quotas/#{space_quota.guid}", nil, user_headers } }

      context 'when the space quota is applied to the space where the current user has a role' do
        let(:expected_codes_and_responses) do
          responses_for_space_restricted_single_endpoint(make_space_quota_json(space_quota))
        end

        it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS
      end

      context 'when the space quota has no associated spaces' do
        let(:api_call) { lambda { |user_headers| get "/v3/space_quotas/#{unapplied_space_quota.guid}", nil, user_headers } }
        let(:unapplied_space_quota) { VCAP::CloudController::SpaceQuotaDefinition.make(organization: org) }

        let(:expected_codes_and_responses) do
          h = Hash.new(code: 404)
          h['admin'] = { code: 200, response_object: make_space_quota_json(unapplied_space_quota) }
          h['admin_read_only'] = { code: 200, response_object: make_space_quota_json(unapplied_space_quota) }
          h['global_auditor'] = { code: 200, response_object: make_space_quota_json(unapplied_space_quota) }
          h['org_manager'] = { code: 200, response_object: make_space_quota_json(unapplied_space_quota) }
          h.freeze
        end

        it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS
      end

      context 'when the space quota is owned by an org where the current user does not have a role' do
        let(:api_call) { lambda { |user_headers| get "/v3/space_quotas/#{other_space_quota.guid}", nil, user_headers } }
        let(:other_org) { VCAP::CloudController::Organization.make }
        let(:other_space_quota) { VCAP::CloudController::SpaceQuotaDefinition.make(organization: other_org) }

        let(:expected_codes_and_responses) do
          h = Hash.new(code: 404)
          h['admin'] = { code: 200, response_object: make_space_quota_json(other_space_quota) }
          h['admin_read_only'] = { code: 200, response_object: make_space_quota_json(other_space_quota) }
          h['global_auditor'] = { code: 200, response_object: make_space_quota_json(other_space_quota) }
          h.freeze
        end

        it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS
      end

      context 'when the space quota does not exist' do
        it 'returns a 404 with a helpful message' do
          get '/v3/space_quotas/not-exist', nil, admin_header

          expect(last_response).to have_status_code(404)
          expect(last_response).to have_error_message('Space quota not found')
        end
      end

      context 'when not logged in' do
        it 'returns a 401 with a helpful message' do
          get '/v3/space_quotas/not-exist', nil, {}
          expect(last_response).to have_status_code(401)
          expect(last_response).to have_error_message('Authentication error')
        end
      end
    end

    describe 'PATCH /v3/space_quotas/:guid' do
      let(:api_call) { lambda { |user_headers| patch "/v3/space_quotas/#{space_quota.guid}", params.to_json, user_headers } }

      let(:params) do
        {
          name: 'don-quixote',
          apps: {
            total_memory_in_mb: 5120,
            per_process_memory_in_mb: 1024,
            total_instances: nil,
            per_app_tasks: 5
          },
          services: {
            paid_services_allowed: false,
            total_service_instances: 10,
            total_service_keys: 20,
          },
          routes: {
            total_routes: 8,
            total_reserved_ports: 4
          }
        }
      end

      let(:updated_space_quota_json) do
        {
          guid: space_quota.guid,
          created_at: iso8601,
          updated_at: iso8601,
          name: 'don-quixote',
          apps: {
            total_memory_in_mb: 5120,
            per_process_memory_in_mb: 1024,
            total_instances: nil,
            per_app_tasks: 5
          },
          services: {
            paid_services_allowed: false,
            total_service_instances: 10,
            total_service_keys: 20
          },
          routes: {
            total_routes: 8,
            total_reserved_ports: 4
          },
          relationships: {
            organization: {
              data: { guid: space_quota.organization.guid },
            },
            spaces: {
              data: [{ guid: space.guid }]
            }
          },
          links: {
            self: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/space_quotas\/#{space_quota.guid}) },
            organization: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/organizations\/#{space_quota.organization.guid}) },
          }
        }
      end

      let(:expected_codes_and_responses) do
        h = Hash.new(code: 403)
        h['admin'] = { code: 200, response_object: updated_space_quota_json }
        h['org_manager'] = { code: 200, response_object: updated_space_quota_json }
        h['org_auditor'] = { code: 404 }
        h['org_billing_manager'] = { code: 404 }
        h['no_role'] = { code: 404 }
        h.freeze
      end

      it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS

      context 'when the space quota does not exist' do
        it 'returns a 404 with a helpful message' do
          patch '/v3/space_quotas/not-exist', params.to_json, admin_header

          expect(last_response).to have_status_code(404)
          expect(last_response).to have_error_message('Space quota not found')
        end
      end

      context 'update partial values' do
        let(:space_quota_to_update) do
          VCAP::CloudController::SpaceQuotaDefinition.make(
            organization: org,
            guid: 'space_quota_to_update_guid',
            name: 'update-me',
            memory_limit: 8,
            non_basic_services_allowed: true)
        end

        let(:partial_params) do
          {
            name: 'don-quixote',
            apps: {
              per_app_tasks: 9,
              total_memory_in_mb: nil,
            },
            services: {
              total_service_instances: 14,
              paid_services_allowed: false,
            },
          }
        end

        before do
          patch "/v3/space_quotas/#{space_quota_to_update.guid}", partial_params.to_json, admin_header
        end

        it 'only updates the requested fields' do
          expect(last_response).to have_status_code(200)
          expect(space_quota_to_update.reload.app_task_limit).to eq(9)
          expect(space_quota_to_update.reload.memory_limit).to eq(-1)
          expect(space_quota_to_update.reload.total_services).to eq(14)
          expect(space_quota_to_update.reload.non_basic_services_allowed).to be_falsey
        end

        context 'patching with empty params' do
          it 'succeeds without changing the quota' do
            patch "/v3/space_quotas/#{space_quota_to_update.guid}", {}, admin_header

            expect(last_response).to have_status_code(200)
            expect(space_quota_to_update.reload.app_task_limit).to eq(9)
            expect(space_quota_to_update.reload.memory_limit).to eq(-1)
            expect(space_quota_to_update.reload.total_services).to eq(14)
            expect(space_quota_to_update.reload.non_basic_services_allowed).to be_falsey
          end
        end
      end

      context 'when trying to update name to a pre-existing name' do
        let!(:new_space_quota) { SpaceQuotaDefinition.make(organization: org) }

        let(:params) do
          {
            name: space_quota.name,
          }
        end

        it 'returns 422' do
          patch "/v3/space_quotas/#{new_space_quota.guid}", params.to_json, admin_header

          expect(last_response).to have_status_code(422)
          expect(last_response).to include_error_message("Space Quota '#{space_quota.name}' already exists.")
        end
      end

      context 'when trying to update name with invalid params' do
        let(:params) do
          {
            wat: 'idk'
          }
        end

        it 'returns 422' do
          patch "/v3/space_quotas/#{space_quota.guid}", params.to_json, admin_header

          expect(last_response).to have_status_code(422)
          expect(last_response).to include_error_message("Unknown field(s): 'wat'")
        end
      end
    end

    describe 'GET /v3/space_quotas' do
      let(:api_call) { lambda { |user_headers| get '/v3/space_quotas', nil, user_headers } }

      it_behaves_like 'list_endpoint_with_common_filters' do
        let(:resource_klass) { VCAP::CloudController::SpaceQuotaDefinition }
        let(:headers) { admin_headers }
        let(:api_call) do
          lambda { |headers, filters| get "/v3/space_quotas?#{filters}", nil, headers }
        end
      end

      context 'when listing space quotas without filters' do
        let!(:unapplied_space_quota) { VCAP::CloudController::SpaceQuotaDefinition.make(organization: org, guid: 'unapplied-space-quota') }

        let(:other_org) { VCAP::CloudController::Organization.make }
        let!(:other_space_quota) { VCAP::CloudController::SpaceQuotaDefinition.make(organization: other_org, guid: 'other-space-quota') }

        let(:expected_codes_and_responses) do
          h = Hash.new(code: 200, response_objects: [])
          h['admin'] = {
            code: 200,
            response_objects: contain_exactly(
              make_space_quota_json(space_quota),
              make_space_quota_json(other_space_quota),
              make_space_quota_json(unapplied_space_quota)
            )
          }
          h['admin_read_only'] = {
            code: 200,
            response_objects: contain_exactly(
              make_space_quota_json(space_quota),
              make_space_quota_json(other_space_quota),
              make_space_quota_json(unapplied_space_quota)
            )
          }
          h['global_auditor'] = {
            code: 200,
            response_objects: contain_exactly(
              make_space_quota_json(space_quota),
              make_space_quota_json(other_space_quota),
              make_space_quota_json(unapplied_space_quota)
            )
          }
          h['org_manager'] = {
            code: 200,
            response_objects: contain_exactly(
              make_space_quota_json(space_quota),
              make_space_quota_json(unapplied_space_quota)
            )
          }
          h['space_manager'] = { code: 200, response_objects: [make_space_quota_json(space_quota)] }
          h['space_auditor'] = { code: 200, response_objects: [make_space_quota_json(space_quota)] }
          h['space_developer'] = { code: 200, response_objects: [make_space_quota_json(space_quota)] }
          h.freeze
        end

        it_behaves_like 'permissions for list endpoint', ALL_PERMISSIONS
      end

      context 'with filters' do
        let!(:space_quota_2) { VCAP::CloudController::SpaceQuotaDefinition.make(guid: 'second-guid', name: 'second-name', organization: org) }
        let(:space_2) { VCAP::CloudController::Space.make(guid: 'space-2-guid', organization: org, space_quota_definition: space_quota_2) }

        let!(:space_quota_3) { VCAP::CloudController::SpaceQuotaDefinition.make(guid: 'third-guid', name: 'third-name', organization: org) }
        let(:space_3) { VCAP::CloudController::Space.make(guid: 'space-3-guid', organization: org, space_quota_definition: space_quota_3) }

        let(:org_alien) { VCAP::CloudController::Organization.make(guid: 'organization-alien-guid') }
        let!(:space_quota_alien) { VCAP::CloudController::SpaceQuotaDefinition.make(guid: 'space-quota-alien-guid', organization: org_alien) }

        it 'returns the list of quotas filtered by names and guids' do
          get "/v3/space_quotas?guids=#{space_quota.guid},second-guid&names=#{space_quota.name},third-name", nil, admin_header

          expect(last_response).to have_status_code(200)
          expect(parsed_response['resources'].length).to eq(1)
          expect(parsed_response['resources'][0]['guid']).to eq(space_quota.guid)
        end

        it 'returns the list of quotas filtered by org guids' do
          get "/v3/space_quotas?organization_guids=#{org_alien.guid}", nil, admin_header

          expect(last_response).to have_status_code(200)
          expect(
            parsed_response['resources'].map { |space_quota| space_quota['guid'] }
          ).to eq([space_quota_alien.guid])
        end

        it 'returns the list of quotas filtered by space guids' do
          get "/v3/space_quotas?space_guids=#{space.guid},#{space_2.guid}", nil, admin_header

          expect(last_response).to have_status_code(200)
          expect(
            parsed_response['resources'].map { |space_quota| space_quota['guid'] }
          ).to eq([space_quota.guid, space_quota_2.guid])
        end
      end

      context 'when the user is not logged in' do
        it 'returns 401 for Unauthenticated requests' do
          get '/v3/space_quotas', nil, base_json_headers
          expect(last_response).to have_status_code(401)
        end
      end

      context 'when the quota is applied to spaces that are not visible to the user' do
        let!(:other_space) do
          VCAP::CloudController::Space.make(
            guid: 'other-space-guid',
            organization: org,
            space_quota_definition: space_quota,
          )
        end
        let(:expected_response) { make_space_quota_json(space_quota, [space]) }

        it 'only shows the guids of spaces that the user has permissions to see' do
          space_manager_header = set_user_with_header_as_role(role: 'space_manager', org: org, space: space, user: user)
          get '/v3/space_quotas', nil, space_manager_header

          expect(last_response).to have_status_code(200)
          expect(parsed_response['resources'][0]).to match_json_response(expected_response)
        end
      end
    end

    describe 'POST /v3/space_quotas' do
      let(:api_call) { lambda { |user_headers| post '/v3/space_quotas', params.to_json, user_headers } }
      let(:params) do
        {
          name: 'quota1',
          relationships: {
            organization: {
              data: { guid: org.guid }
            }
          }
        }
      end

      context 'specifying only the required params' do
        let(:space_quota_json) do
          {
            guid: UUID_REGEX,
            created_at: iso8601,
            updated_at: iso8601,
            name: params[:name],
            apps: {
              total_memory_in_mb: nil,
              per_process_memory_in_mb: nil,
              total_instances: nil,
              per_app_tasks: nil
            },
            services: {
              paid_services_allowed: true,
              total_service_instances: nil,
              total_service_keys: nil
            },
            routes: {
              total_routes: nil,
              total_reserved_ports: nil
            },
            relationships: {
              organization: {
                data: { guid: org.guid },
              },
              spaces: {
                data: []
              }
            },
            links: {
              self: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/space_quotas\/#{params[:guid]}) },
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
            response_object: space_quota_json
          }
          h['org_manager'] = {
            code: 201,
            response_object: space_quota_json
          }
          h.freeze
        end

        it 'creates a space_quota' do
          expect {
            api_call.call(admin_header)
          }.to change {
            SpaceQuotaDefinition.count
          }.by 1
        end

        it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS
      end

      context 'passing empty limit objects' do
        let(:params) do
          {
            name: 'quota1',
            apps: {},
            services: {},
            routes: {},
            relationships: {
              organization: {
                data: { guid: org.guid }
              }
            }
          }
        end

        let(:space_quota_json) do
          {
            guid: UUID_REGEX,
            created_at: iso8601,
            updated_at: iso8601,
            name: params[:name],
            apps: {
              total_memory_in_mb: nil,
              per_process_memory_in_mb: nil,
              total_instances: nil,
              per_app_tasks: nil
            },
            services: {
              paid_services_allowed: true,
              total_service_instances: nil,
              total_service_keys: nil
            },
            routes: {
              total_routes: nil,
              total_reserved_ports: nil
            },
            relationships: {
              organization: {
                data: { guid: org.guid },
              },
              spaces: {
                data: []
              }
            },
            links: {
              self: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/space_quotas\/#{params[:guid]}) },
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
            response_object: space_quota_json
          }
          h['org_manager'] = {
            code: 201,
            response_object: space_quota_json
          }
          h.freeze
        end

        it 'creates a space_quota' do
          expect {
            api_call.call(admin_header)
          }.to change {
            SpaceQuotaDefinition.count
          }.by 1
        end

        it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS
      end

      context 'specifying all possible params' do
        let(:params) do
          {
            name: 'my-space-quota',
            apps: {
              total_memory_in_mb: 5120,
              per_process_memory_in_mb: 1024,
              total_instances: 10,
              per_app_tasks: 5
            },
            services: {
              paid_services_allowed: false,
              total_service_instances: 11,
              total_service_keys: 12
            },
            routes: {
              total_routes: 47,
              total_reserved_ports: 2
            },
            relationships: {
              organization: {
                data: { guid: org.guid }
              },
              spaces: {
                data: [
                  { guid: space.guid }
                ]
              }
            }
          }
        end

        let(:expected_response) do
          {
            guid: UUID_REGEX,
            created_at: iso8601,
            updated_at: iso8601,
            name: 'my-space-quota',
            apps: {
              total_memory_in_mb: 5120,
              per_process_memory_in_mb: 1024,
              total_instances: 10,
              per_app_tasks: 5
            },
            services: {
              paid_services_allowed: false,
              total_service_instances: 11,
              total_service_keys: 12
            },
            routes: {
              total_routes: 47,
              total_reserved_ports: 2
            },
            relationships: {
              organization: {
                data: {
                  guid: org.guid
                }
              },
              spaces: {
                data: [
                  { guid: space.guid }
                ]
              }
            },
            links: {
              self: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/space_quotas\/#{params[:guid]}) },
              organization: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/organizations\/#{org.guid}) },
            }
          }
        end

        it 'creates a space quota with the requested limits' do
          api_call.call(admin_header)
          expect(last_response).to have_status_code(201)
          expect(parsed_response).to match_json_response(expected_response)
        end
      end

      context 'when the org guid is invalid' do
        let(:params) do
          {
            name: 'quota-with-bad-org',
            relationships: {
              organization: {
                data: { guid: 'not-real' }
              }
            }
          }
        end

        it 'returns 422' do
          post '/v3/space_quotas', params.to_json, admin_header

          expect(last_response).to have_status_code(422)
          expect(last_response).to include_error_message('Organization with guid \'not-real\' does not exist, or you do not have access to it.')
        end
      end

      context 'when the space guid is invalid' do
        let(:params) do
          {
            name: 'quota-with-bad-space',
            relationships: {
              organization: {
                data: { guid: org.guid }
              },
              spaces: {
                data: [
                  { guid: 'not-real' }
                ]
              }
            }
          }
        end

        it 'returns 422' do
          post '/v3/space_quotas', params.to_json, admin_header

          expect(last_response).to have_status_code(422)
          expect(last_response).to include_error_message('Spaces with guids ["not-real"] do not exist within the organization specified, or you do not have access to them.')
        end
      end

      context 'when the user is not logged in' do
        it 'returns 401 for Unauthenticated requests' do
          post '/v3/space_quotas', params.to_json, base_json_headers
          expect(last_response).to have_status_code(401)
        end
      end

      context 'when the params are invalid' do
        let(:headers) { set_user_with_header_as_role(role: 'admin') }

        context 'when provided invalid arguments' do
          let(:params) do
            {
              name: 555,
            }
          end

          it 'returns 422' do
            post '/v3/space_quotas', params.to_json, headers

            expect(last_response).to have_status_code(422)
            expect(last_response).to include_error_message('Name must be a string')
          end
        end

        context 'with a pre-existing name' do
          let(:params) do
            {
              name: 'double-trouble',
              relationships: {
                organization: {
                  data: { guid: org.guid }
                }
              }
            }
          end

          it 'returns 422' do
            post '/v3/space_quotas', params.to_json, headers
            post '/v3/space_quotas', params.to_json, headers

            expect(last_response).to have_status_code(422)
            expect(last_response).to include_error_message("Space Quota 'double-trouble' already exists.")
          end
        end
      end
    end

    describe 'POST /v3/space_quotas/:guid/relationships/spaces' do
      let(:api_call) { lambda { |user_headers| post "/v3/space_quotas/#{space_quota.guid}/relationships/spaces", params.to_json, user_headers } }
      let(:other_space) { VCAP::CloudController::Space.make(organization: org, guid: 'other-space-guid') }

      let(:params) do
        {
          data: [{ guid: other_space.guid }]
        }
      end

      context 'when applying quota to a space' do
        let(:data_json) do
          {
            data: a_collection_containing_exactly(
              { guid: space.guid },
              { guid: other_space.guid }
            ),
            links: {
              self: { href: "#{link_prefix}/v3/space_quotas/#{space_quota.guid}/relationships/spaces" },
            }
          }
        end

        let(:expected_codes_and_responses) do
          h = Hash.new(code: 403)
          h['admin'] = { code: 200, response_object: data_json }
          h['org_manager'] = { code: 200, response_object: data_json }
          h['org_auditor'] = { code: 404 }
          h['org_billing_manager'] = { code: 404 }
          h['no_role'] = { code: 404 }
          h
        end

        it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS
      end

      context 'when a space does not exist' do
        let(:params) do
          {
            data: [
              { guid: 'not a real guid' }
            ]
          }
        end

        it 'returns a 422 with a helpful message' do
          post "/v3/space_quotas/#{space_quota.guid}/relationships/spaces", params.to_json, admin_header
          expect(last_response).to have_status_code(422)
          expect(last_response).to have_error_message('Spaces with guids ["not a real guid"] do not exist, or you do not have access to them.')
        end
      end

      context 'when a guid in the request body is the wrong type' do
        let(:bad_params) do
          {
            data: [
              { guid: space.guid },
              { guid: 6 }
            ]
          }
        end

        it 'returns a helpful error message' do
          post "/v3/space_quotas/#{space_quota.guid}/relationships/spaces", bad_params.to_json, admin_header

          expect(last_response).to have_status_code(422)
          expect(parsed_response['errors'][0]['detail']).to eq('Invalid data type: Data[1] guid should be a string.')
        end
      end
    end

    describe 'DELETE /v3/space_quotas/:guid/relationships/spaces' do
      let(:api_call) { lambda { |user_headers| delete "/v3/space_quotas/#{space_quota.guid}/relationships/spaces/#{space.guid}", {}, user_headers } }

      context 'when removing a space quota from a space' do
        let(:expected_codes_and_responses) do
          h = Hash.new(code: 403)
          h['admin'] = { code: 204 }
          h['org_manager'] = { code: 204 }
          h['org_auditor'] = { code: 404 }
          h['org_billing_manager'] = { code: 404 }
          h['no_role'] = { code: 404 }
          h
        end

        let(:db_check) do
          lambda do
            expect(space_quota.reload.spaces.count).to eq(0)
            expect(space.reload.space_quota_definition_guid).to be_nil
          end
        end

        it_behaves_like 'permissions for delete endpoint', ALL_PERMISSIONS
      end

      context 'when the space does not exist' do
        let(:fake_space_guid) { 'does-not-exist' }

        it 'returns a helpful error message' do
          delete "/v3/space_quotas/#{space_quota.guid}/relationships/spaces/#{fake_space_guid}", {}, admin_header

          expect(last_response).to have_status_code(422)
          expect(last_response).to include_error_message("Unable to remove quota from space with guid 'does-not-exist'. Ensure the space quota is applied to this space.")
        end
      end

      context 'when the space is not associated with the quota' do
        let(:other_space) { VCAP::CloudController::Space.make(guid: 'not-related-space') }

        it 'returns a helpful error message' do
          delete "/v3/space_quotas/#{space_quota.guid}/relationships/spaces/#{other_space.guid}", {}, admin_header

          expect(last_response).to have_status_code(422)
          expect(last_response).to include_error_message("Unable to remove quota from space with guid 'not-related-space'. Ensure the space quota is applied to this space.")
        end
      end
    end

    describe 'DELETE /v3/space_quotas/:guid' do
      context 'when deleting a space quota that is not applied to any spaces' do
        let(:api_call) { lambda { |user_headers| delete "/v3/space_quotas/#{unapplied_space_quota.guid}", {}, user_headers } }
        let!(:unapplied_space_quota) { VCAP::CloudController::SpaceQuotaDefinition.make(organization: org, guid: 'unapplied-space-quota') }

        let(:expected_codes_and_responses) do
          h = Hash.new(code: 404)
          h['admin'] = { code: 202 }
          h['org_manager'] = { code: 202 }
          h['admin_read_only'] = { code: 403 }
          h['global_auditor'] = { code: 403 }
          h
        end

        let(:db_check) do
          lambda do
            last_job = VCAP::CloudController::PollableJobModel.last
            expect(last_response.headers['Location']).to match(%r(/v3/jobs/#{last_job.guid}))
            expect(last_job.resource_type).to eq('space_quota')

            get "/v3/jobs/#{last_job.guid}", nil, admin_header
            expect(last_response).to have_status_code(200)
            expect(parsed_response['operation']).to eq('space_quota.delete')
            expect(parsed_response['links']['space_quota']['href']).to match(%r(/v3/space_quotas/#{unapplied_space_quota.guid}))

            execute_all_jobs(expected_successes: 1, expected_failures: 0)

            get "/v3/space_quotas/#{unapplied_space_quota.guid}", nil, admin_header
            expect(last_response).to have_status_code(404)
          end
        end

        it_behaves_like 'permissions for delete endpoint', ALL_PERMISSIONS
      end

      context 'when the space quota does not exist' do
        let(:fake_space_quota_guid) { 'does-not-exist' }

        it 'returns a 404 with a helpful error message' do
          delete "/v3/space_quotas/#{fake_space_quota_guid}", {}, admin_header

          expect(last_response).to have_status_code(404)
          expect(last_response).to have_error_message('Space quota not found')
        end
      end

      context 'when the space quota is still applied to a space' do
        let!(:space) { VCAP::CloudController::Space.make(space_quota_definition: space_quota, organization: org) }
        let(:api_call) { lambda { |user_headers| delete "/v3/space_quotas/#{space_quota.guid}", {}, user_headers } }

        let(:expected_codes_and_responses) do
          h = Hash.new(code: 403)
          h['admin'] = { code: 422 }
          h['org_manager'] = { code: 422 }
          h['org_auditor'] = { code: 404 }
          h['org_billing_manager'] = { code: 404 }
          h['no_role'] = { code: 404 }
          h
        end

        let(:db_check) do
          lambda do
            get "/v3/space_quotas/#{space_quota.guid}", nil, admin_header
            expect(last_response).to have_status_code(200)
          end
        end

        it_behaves_like 'permissions for delete endpoint', ALL_PERMISSIONS

        context 'when the user has sufficient permissions to delete a space quota' do
          it 'returns a 422 with a helpful error message' do
            delete "/v3/space_quotas/#{space_quota.guid}", {}, admin_header

            expect(last_response).to have_status_code(422)
            expect(last_response).to have_error_message('This quota is applied to one or more spaces. Remove this quota from all spaces before deleting.')
          end
        end
      end
    end

    def make_space_quota_json(space_quota, associated_spaces=space_quota.spaces)
      {
        guid: space_quota.guid,
        created_at: iso8601,
        updated_at: iso8601,
        name: space_quota.name,
        apps: {
          total_memory_in_mb: 20480,
          per_process_memory_in_mb: nil,
          total_instances: nil,
          per_app_tasks: 5
        },
        services: {
          paid_services_allowed: true,
          total_service_instances: 60,
          total_service_keys: 600
        },
        routes: {
          total_routes: 1000,
          total_reserved_ports: nil
        },
        relationships: {
          organization: {
            data: { guid: space_quota.organization.guid },
          },
          spaces: {
            data: associated_spaces.map { |space| { guid: space.guid } }
          }
        },
        links: {
          self: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/space_quotas\/#{space_quota.guid}) },
          organization: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/organizations\/#{space_quota.organization.guid}) },
        }
      }
    end
  end
end
