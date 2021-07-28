require 'spec_helper'
require 'request_spec_shared_examples'

module VCAP::CloudController
  RSpec.describe 'organization_quotas' do
    let(:user) { VCAP::CloudController::User.make(guid: 'user-guid') }
    let(:organization_quota) { VCAP::CloudController::QuotaDefinition.make(guid: 'org-quota-guid') }
    let!(:org) { VCAP::CloudController::Organization.make(guid: 'organization-guid', quota_definition: organization_quota) }
    let(:space) { VCAP::CloudController::Space.make(guid: 'space-guid', organization: org) }
    let(:admin_header) { headers_for(user, scopes: %w(cloud_controller.admin)) }

    describe 'POST /v3/organization_quotas' do
      let(:api_call) { lambda { |user_headers| post '/v3/organization_quotas', params.to_json, user_headers } }

      let(:params) do
        {
          name: 'quota1',
          relationships: {
            organizations: {
              data: [
                { guid: org.guid },
              ]
            }
          }
        }
      end

      let(:organization_quota_json) do
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
            total_reserved_ports: nil,
          },
          domains: {
            total_domains: nil,
          },
          relationships: {
            organizations: {
              data: [{ guid: 'organization-guid' }],
            }
          },
          links: {
            self: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/organization_quotas\/#{params[:guid]}) },
          }
        }
      end

      let(:expected_codes_and_responses) do
        h = Hash.new(
          code: 403,
        )
        h['admin'] = {
          code: 201,
          response_object: organization_quota_json
        }
        h.freeze
      end

      context 'using the default params' do
        it 'creates a organization_quota' do
          expect {
            api_call.call(admin_header)
          }.to change {
            QuotaDefinition.count
          }.by 1
        end

        it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS
      end

      context 'using provided params' do
        let(:params) do
          {
            name: 'org1',
            apps: {
              total_memory_in_mb: 5120,
              per_process_memory_in_mb: 1024,
              total_instances: 10,
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
            domains: {
              total_domains: 7,
            },
          }
        end

        let(:expected_response) do
          {
            guid: UUID_REGEX,
            created_at: iso8601,
            updated_at: iso8601,
            name: 'org1',
            apps: {
              total_memory_in_mb: 5120,
              per_process_memory_in_mb: 1024,
              total_instances: 10,
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
            domains: {
              total_domains: 7,
            },
            relationships: {
              organizations: {
                data: [],
              },
            },
            links: {
              self: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/organization_quotas\/#{params[:guid]}) },
            }
          }
        end

        it 'responds with the expected code and response' do
          api_call.call(admin_header)
          expect(last_response).to have_status_code(201)
          expect(parsed_response).to match_json_response(expected_response)
        end
      end

      context 'when the user is not logged in' do
        it 'returns 401 for Unauthenticated requests' do
          post '/v3/organization_quotas', params.to_json, base_json_headers
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
            post '/v3/organization_quotas', params.to_json, headers

            expect(last_response).to have_status_code(422)
            expect(last_response).to include_error_message('Name must be a string')
          end
        end

        context 'with a pre-existing name' do
          let(:params) do
            {
              name: 'double-trouble',
            }
          end

          it 'returns 422' do
            post '/v3/organization_quotas', params.to_json, headers
            post '/v3/organization_quotas', params.to_json, headers

            expect(last_response).to have_status_code(422)
            expect(last_response).to include_error_message("Organization Quota 'double-trouble' already exists.")
          end
        end
      end
    end

    describe 'GET /v3/organization_quotas' do
      let(:api_call) { lambda { |user_headers| get '/v3/organization_quotas', nil, user_headers } }

      context 'when listing organization_quotas' do
        let!(:other_org) { VCAP::CloudController::Organization.make(guid: 'other-organization-guid', quota_definition: organization_quota) }
        let(:other_org_response) { { guid: 'other-organization-guid' } }
        let(:org_response) { { guid: 'organization-guid' } }

        let(:expected_codes_and_responses) do
          h = Hash.new(code: 200, response_objects: generate_org_quota_list_response([org_response], false))
          h['admin'] = { code: 200, response_objects: generate_org_quota_list_response([org_response, other_org_response], true) }
          h['admin_read_only'] = { code: 200, response_objects: generate_org_quota_list_response([org_response, other_org_response], true) }
          h['global_auditor'] = { code: 200, response_objects: generate_org_quota_list_response([org_response, other_org_response], true) }
          h['no_role'] = { code: 200, response_objects: generate_org_quota_list_response([], false) }
          h
        end

        it_behaves_like 'permissions for list endpoint', ALL_PERMISSIONS

        it_behaves_like 'list_endpoint_with_common_filters' do
          let(:resource_klass) { VCAP::CloudController::QuotaDefinition }
          let(:api_call) do
            lambda { |headers, filters| get "/v3/organization_quotas?#{filters}", nil, headers }
          end
          let(:headers) { admin_headers }
        end

        context 'with filters' do
          let!(:organization_quota_2) { VCAP::CloudController::QuotaDefinition.make(guid: 'second-guid', name: 'second-name') }
          let!(:organization_quota_3) { VCAP::CloudController::QuotaDefinition.make(guid: 'third-guid', name: 'third-name') }

          before do
            org.quota_definition = organization_quota
            org.save

            other_org.quota_definition = organization_quota
            other_org.save
          end

          it 'returns the list of quotas filtered by names and guids' do
            get "/v3/organization_quotas?guids=#{organization_quota.guid},second-guid&names=#{organization_quota.name},third-name", nil, admin_header

            expect(last_response).to have_status_code(200)
            expect(parsed_response['resources'].length).to eq(1)
            expect(parsed_response['resources'][0]['guid']).to eq(organization_quota.guid)
          end

          it 'returns the list of quotas filtered by organization guids' do
            get "/v3/organization_quotas?organization_guids=#{org.guid},#{other_org.guid}", nil, admin_header

            expect(last_response).to have_status_code(200)
            expect(
              parsed_response['resources'].map { |org_quota| org_quota['guid'] }
            ).to eq([organization_quota.guid])
          end
        end
      end

      context 'when not logged in' do
        it 'returns a 401 with a helpful message' do
          get '/v3/organization_quotas', nil, {}
          expect(last_response).to have_status_code(401)
          expect(last_response).to have_error_message('Authentication error')
        end
      end
    end

    describe 'GET /v3/organization_quotas/:guid' do
      let(:api_call) { lambda { |user_headers| get "/v3/organization_quotas/#{organization_quota.guid}", nil, user_headers } }

      context 'when getting an organization_quota' do
        let!(:other_org) { VCAP::CloudController::Organization.make(guid: 'other-organization-guid', quota_definition: organization_quota) }
        let(:other_org_response) { { guid: 'other-organization-guid' } }
        let(:org_response) { { guid: 'organization-guid' } }

        let(:expected_codes_and_responses) do
          h = Hash.new(code: 200, response_object: generate_org_quota_single_response([org_response]))
          h['admin'] = { code: 200, response_object: generate_org_quota_single_response([org_response, other_org_response]) }
          h['admin_read_only'] = { code: 200, response_object: generate_org_quota_single_response([org_response, other_org_response]) }
          h['global_auditor'] = { code: 200, response_object: generate_org_quota_single_response([org_response, other_org_response]) }
          h['no_role'] = { code: 200, response_object: generate_org_quota_single_response([]) }
          h
        end

        it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS
      end

      context 'when the organization_quota had no associated organizations' do
        let(:unused_organization_quota) { VCAP::CloudController::QuotaDefinition.make }

        it 'returns a quota with an empty array of org guids' do
          get "/v3/organization_quotas/#{unused_organization_quota.guid}", nil, admin_header

          expect(last_response).to have_status_code(200)
          expect(parsed_response['relationships']['organizations']['data']).to eq([])
        end
      end

      context 'when the organization_quota does not exist' do
        it 'returns a 404 with a helpful message' do
          get '/v3/organization_quotas/not-exist', nil, admin_header

          expect(last_response).to have_status_code(404)
          expect(last_response).to have_error_message('Organization quota not found')
        end
      end

      context 'when not logged in' do
        it 'returns a 401 with a helpful message' do
          get '/v3/organization_quotas/not-exist', nil, {}
          expect(last_response).to have_status_code(401)
          expect(last_response).to have_error_message('Authentication error')
        end
      end
    end

    describe 'PATCH /v3/organization_quotas/:guid' do
      let(:api_call) { lambda { |user_headers| patch "/v3/organization_quotas/#{organization_quota.guid}", params.to_json, user_headers } }

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
          },
          domains: {
            total_domains: 7
          }
        }
      end

      let(:organization_quota_json) do
        {
          guid: organization_quota.guid,
          created_at: iso8601,
          updated_at: iso8601,
          name: params[:name],
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
          },
          domains: {
            total_domains: 7,
          },
          relationships: {
            organizations: {
              data: [{ guid: 'organization-guid' }],
            }
          },
          links: {
            self: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/organization_quotas\/#{params[:guid]}) },
          }
        }
      end

      let(:expected_codes_and_responses) do
        h = Hash.new(
          code: 403,
        )
        h['admin'] = {
          code: 200,
          response_object: organization_quota_json
        }
        h.freeze
      end

      it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS

      context 'when the organization_quota does not exist' do
        it 'returns a 404 with a helpful message' do
          patch '/v3/organization_quotas/not-exist', params.to_json, admin_header

          expect(last_response).to have_status_code(404)
          expect(last_response).to have_error_message('Organization quota not found')
        end
      end

      context 'update partial values' do
        let(:org_quota_to_update) { VCAP::CloudController::QuotaDefinition.make(
          guid: 'org_quota_to_update_guid',
          name: 'update-me',
          memory_limit: 8,
          non_basic_services_allowed: true)
        }
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
          patch "/v3/organization_quotas/#{org_quota_to_update.guid}", partial_params.to_json, admin_header
        end

        it 'only updates the requested fields' do
          expect(last_response).to have_status_code(200)
          expect(org_quota_to_update.reload.app_task_limit).to eq(9)
          expect(org_quota_to_update.reload.memory_limit).to eq(-1)
          expect(org_quota_to_update.reload.total_services).to eq(14)
          expect(org_quota_to_update.reload.non_basic_services_allowed).to be_falsey
        end

        context 'patching with empty params' do
          it 'succeeds without changing the quota' do
            patch "/v3/organization_quotas/#{org_quota_to_update.guid}", {}, admin_header

            expect(last_response).to have_status_code(200)
            expect(org_quota_to_update.reload.app_task_limit).to eq(9)
            expect(org_quota_to_update.reload.memory_limit).to eq(-1)
            expect(org_quota_to_update.reload.total_services).to eq(14)
            expect(org_quota_to_update.reload.non_basic_services_allowed).to be_falsey
          end
        end
      end

      context 'when trying to update name to a pre-existing name' do
        let(:new_org_quota) { QuotaDefinition.make }

        let(:params) do
          {
            name: organization_quota.name,
          }
        end

        it 'returns 422' do
          patch "/v3/organization_quotas/#{new_org_quota.guid}", params.to_json, admin_header

          expect(last_response).to have_status_code(422)
          expect(last_response).to include_error_message("Organization Quota '#{organization_quota.name}' already exists.")
        end
      end
    end

    describe 'POST /v3/organization_quotas/:guid/relationships/organizations' do
      let(:api_call) { lambda { |user_headers| post "/v3/organization_quotas/#{org_quota.guid}/relationships/organizations", params.to_json, user_headers } }

      let(:org) { VCAP::CloudController::Organization.make }
      let(:org_quota) { VCAP::CloudController::QuotaDefinition.make }

      let(:params) do
        {
          data: [{ guid: org.guid }]
        }
      end

      context 'when applying quota to an organization' do
        let(:data_json) do
          {
            data: [
              { guid: org.guid }
            ],
            links: {
              self: { href: "#{link_prefix}/v3/organization_quotas/#{org_quota.guid}/relationships/organizations" },
            }
          }
        end

        let(:expected_codes_and_responses) do
          h = Hash.new(code: 403)
          h['admin'] = { code: 200, response_object: data_json }
          h
        end

        it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS
      end

      context 'when an org guid does not exist' do
        let(:params) do
          {
            data: [{ guid: 'not a real guid' }]
          }
        end

        it 'returns a 422 with a helpful message' do
          post "/v3/organization_quotas/#{org_quota.guid}/relationships/organizations", params.to_json, admin_header
          expect(last_response).to have_status_code(422)
          expect(last_response).to have_error_message('Organizations with guids ["not a real guid"] do not exist, or you do not have access to them.')
        end
      end

      context 'when an org guid is the wrong type' do
        let(:params) do
          {
            data: [{ guid: 8 }]
          }
        end

        it 'returns a 422 with a helpful message' do
          post "/v3/organization_quotas/#{org_quota.guid}/relationships/organizations", params.to_json, admin_header
          expect(last_response).to have_status_code(422)
          expect(parsed_response['errors'][0]['detail']).to eq('Invalid data type: Data[0] guid should be a string.')
        end
      end
    end

    describe 'DELETE /v3/organization_quotas/:guid/' do
      let(:org_quota) { VCAP::CloudController::QuotaDefinition.make }
      let(:api_call) { lambda { |user_headers| delete "/v3/organization_quotas/#{org_quota.guid}", nil, user_headers } }
      let(:db_check) do
        lambda do
          expect(last_response.headers['Location']).to match(%r(http.+/v3/jobs/[a-fA-F0-9-]+))

          execute_all_jobs(expected_successes: 1, expected_failures: 0)

          last_job = VCAP::CloudController::PollableJobModel.last
          expect(last_response.headers['Location']).to match(%r(/v3/jobs/#{last_job.guid}))
          expect(last_job.resource_type).to eq('organization_quota')
        end
      end

      context 'when deleting an organization quota' do
        let(:expected_codes_and_responses) do
          h = Hash.new(code: 403)
          h['admin'] = { code: 202 }
          h
        end

        it_behaves_like 'permissions for delete endpoint', ALL_PERMISSIONS
      end

      context 'when the user is not logged in' do
        it 'returns 401 for Unauthenticated requests' do
          delete "/v3/organization_quotas/#{org_quota.guid}", nil, base_json_headers
          expect(last_response.status).to eq(401)
        end
      end

      context 'when an organization quota is applied to an organization' do
        let(:org) { VCAP::CloudController::Organization.make }

        let(:params) do
          {
            data: [{ guid: org.guid }]
          }
        end

        it 'the org quota is not  deleted and returns a 422' do
          post "/v3/organization_quotas/#{org_quota.guid}/relationships/organizations", params.to_json, admin_headers

          delete "/v3/organization_quotas/#{org_quota.guid}", nil, admin_headers
          expect(last_response).to have_status_code(422)

          get "/v3/organization_quotas/#{org_quota.guid}", {}, admin_headers
          expect(last_response.status).to eq(200)
        end
      end

      context 'when an organization_quota guid is invalid' do
        it 'returns a 404 with a helpful message' do
          delete '/v3/organization_quotas/fake_org_quota', nil, admin_headers
          expect(last_response).to have_status_code(404)
        end
      end
    end
  end
end

def generate_org_quota_single_response(list_of_orgs)
  {
    guid: organization_quota.guid,
    created_at: iso8601,
    updated_at: iso8601,
    name: organization_quota.name,
    apps: {
      total_memory_in_mb: 20480,
      per_process_memory_in_mb: nil,
      total_instances: nil,
      per_app_tasks: nil
    },
    services: {
      paid_services_allowed: true,
      total_service_instances: 60,
      total_service_keys: nil,
    },
    routes: {
      total_routes: 1000,
      total_reserved_ports: 5
    },
    domains: {
      total_domains: nil
    },
    relationships: {
      organizations: {
        data: contain_exactly(*list_of_orgs)
      }
    },
    links: {
      self: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/organization_quotas\/#{organization_quota.guid}) },
    }
  }
end

def generate_org_quota_list_response(list_of_orgs, global_read)
  [
    generate_default_org_quota_response(global_read),
    generate_org_quota_single_response(list_of_orgs),
  ]
end

def generate_default_org_quota_response(global_read)
  # our request specs are seeded with an org that uses the default org quota
  # the visibility of this org depends on the user's permissions
  seeded_org_guid = VCAP::CloudController::Organization.where(name: 'the-system_domain-org-name').first.guid
  seeded_org = global_read ? [{ guid: seeded_org_guid }] : []

  default_quota = VCAP::CloudController::QuotaDefinition.default
  {
    guid: default_quota.guid,
    created_at: iso8601,
    updated_at: iso8601,
    name: default_quota.name,
    apps: {
      total_memory_in_mb: 10240,
      per_process_memory_in_mb: nil,
      total_instances: nil,
      per_app_tasks: nil
    },
    services: {
      paid_services_allowed: true,
      total_service_instances: 100,
      total_service_keys: nil,
    },
    routes: {
      total_routes: 1000,
      total_reserved_ports: 0
    },
    domains: {
      total_domains: nil
    },
    relationships: {
      organizations: {
        data: seeded_org
      }
    },
    links: {
      self: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/organization_quotas\/#{default_quota.guid}) },
    }
  }
end
