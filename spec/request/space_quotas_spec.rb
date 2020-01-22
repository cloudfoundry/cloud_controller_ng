require 'spec_helper'
require 'request_spec_shared_examples'

module VCAP::CloudController
  RSpec.describe 'space_quotas' do
    let(:user) { VCAP::CloudController::User.make(guid: 'user-guid') }
    let!(:org) { VCAP::CloudController::Organization.make(guid: 'organization-guid') }
    let(:space_quota) { VCAP::CloudController::SpaceQuotaDefinition.make(guid: 'space-quota-guid', organization: org) }
    let(:space) { VCAP::CloudController::Space.make(guid: 'space-guid', organization: org, space_quota_definition: space_quota) }
    let(:admin_header) { headers_for(user, scopes: %w(cloud_controller.admin)) }

    describe 'POST /v3/space_quotas' do
      let(:api_call) { lambda { |user_headers| post '/v3/space_quotas', params.to_json, user_headers } }
      let(:params) do
        {
          'name': 'quota1',
          'relationships': {
            'organization': {
              'data': { 'guid': org.guid }
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
                data: { 'guid': org.guid },
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
            'name': 'quota1',
            'apps': {},
            'services': {},
            'routes': {},
            'relationships': {
              'organization': {
                'data': { 'guid': org.guid }
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
                data: { 'guid': org.guid },
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
            'name': 'my-space-quota',
            'apps': {
              'total_memory_in_mb': 5120,
              'per_process_memory_in_mb': 1024,
              'total_instances': 10,
              'per_app_tasks': 5
            },
            'services': {
              'paid_services_allowed': false,
              'total_service_instances': 11,
              'total_service_keys': 12
            },
            routes: {
              total_routes: 47,
              total_reserved_ports: 2
            },
            'relationships': {
              'organization': {
                'data': { 'guid': org.guid }
              },
              'spaces': {
                'data': [
                  { 'guid': space.guid }
                ]
              }
            }
          }
        end

        let(:expected_response) do
          {
            'guid': UUID_REGEX,
            'created_at': iso8601,
            'updated_at': iso8601,
            'name': 'my-space-quota',
            'apps': {
              'total_memory_in_mb': 5120,
              'per_process_memory_in_mb': 1024,
              'total_instances': 10,
              'per_app_tasks': 5
            },
            'services': {
              'paid_services_allowed': false,
              'total_service_instances': 11,
              'total_service_keys': 12
            },
            routes: {
              total_routes: 47,
              total_reserved_ports: 2
            },
            'relationships': {
              'organization': {
                'data': {
                  'guid': org.guid
                }
              },
              'spaces': {
                'data': [
                  { 'guid': space.guid }
                ]
              }
            },
            'links': {
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
          expect(last_response).to include_error_message('Spaces with guids ["not-real"] do not exist, or you do not have access to them.')
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
  end
end
