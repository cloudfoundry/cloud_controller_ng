require 'spec_helper'

RSpec.describe 'Routes' do
  let(:user) { VCAP::CloudController::User.make }
  let(:space) { VCAP::CloudController::Space.make }

  before do
    space.organization.add_user(user)
    space.add_developer(user)

    stub_request(:post, 'http://routing-client:routing-secret@localhost:8080/uaa/oauth/token').
      with(body: 'grant_type=client_credentials').
      to_return(status: 200,
                body:           '{"token_type": "monkeys", "access_token": "banana"}',
                headers:        { 'content-type' => 'application/json' })

    stub_request(:get, 'http://localhost:3000/routing/v1/router_groups').
      to_return(status: 200, body: '{}', headers: {})
  end

  describe 'GET /v2/routes' do
    let!(:route) { VCAP::CloudController::Route.make(domain: domain, space: space) }
    let(:domain) { VCAP::CloudController::SharedDomain.make }

    it 'lists all routes' do
      get '/v2/routes', nil, headers_for(user)

      expect(last_response.status).to eq(200)

      parsed_response = MultiJson.load(last_response.body)
      expect(parsed_response).to be_a_response_like(
        {
          'total_results' => 1,
          'total_pages'   => 1,
          'prev_url'      => nil,
          'next_url'      => nil,
          'resources'     => [{
            'metadata' => {
              'guid'       => route.guid,
              'url'        => "/v2/routes/#{route.guid}",
              'created_at' => iso8601,
              'updated_at' => nil
            },
            'entity' => {
              'host'                  => route.host,
              'path'                  => '',
              'domain_guid'           => domain.guid,
              'space_guid'            => space.guid,
              'service_instance_guid' => nil,
              'port'                  => nil,
              'domain_url'            => "/v2/shared_domains/#{domain.guid}",
              'space_url'             => "/v2/spaces/#{space.guid}",
              'apps_url'              => "/v2/routes/#{route.guid}/apps",
              'route_mappings_url'    => "/v2/routes/#{route.guid}/route_mappings"
            }
          }]
        }
      )
    end

    context 'with inline-relations-depth' do
      let!(:process) { VCAP::CloudController::AppFactory.make(space: space) }
      let!(:route_mapping) { VCAP::CloudController::RouteMapping.make(app: process, route: route) }

      it 'includes related records' do
        get '/v2/routes?inline-relations-depth=1', nil, headers_for(user)

        expect(last_response.status).to eq(200)

        parsed_response = MultiJson.load(last_response.body)
        expect(parsed_response).to be_a_response_like(
          {
            'total_results' => 1,
            'total_pages'   => 1,
            'prev_url'      => nil,
            'next_url'      => nil,
            'resources'     => [{
              'metadata' => {
                'guid'       => route.guid,
                'url'        => "/v2/routes/#{route.guid}",
                'created_at' => iso8601,
                'updated_at' => nil
              },
              'entity' => {
                'host'                  => route.host,
                'path'                  => '',
                'domain_guid'           => domain.guid,
                'space_guid'            => space.guid,
                'service_instance_guid' => nil,
                'port'                  => nil,
                'domain_url'            => "/v2/shared_domains/#{domain.guid}",
                'domain'                => {
                  'metadata' => {
                    'guid'       => domain.guid,
                    'url'        => "/v2/shared_domains/#{domain.guid}",
                    'created_at' => iso8601,
                    'updated_at' => nil
                  },
                  'entity' => {
                    'name'              => domain.name,
                    'router_group_guid' => nil,
                    'router_group_type' => nil
                  }
                },
                'space_url'             => "/v2/spaces/#{space.guid}",
                'space'                 => {
                  'metadata' => {
                    'guid'       => space.guid,
                    'url'        => "/v2/spaces/#{space.guid}",
                    'created_at' => iso8601,
                    'updated_at' => nil
                  },
                  'entity' => {
                    'name'                        => space.name,
                    'organization_guid'           => space.organization.guid.to_s,
                    'space_quota_definition_guid' => nil,
                    'allow_ssh'                   => true,
                    'organization_url'            => "/v2/organizations/#{space.organization.guid}",
                    'developers_url'              => "/v2/spaces/#{space.guid}/developers",
                    'managers_url'                => "/v2/spaces/#{space.guid}/managers",
                    'auditors_url'                => "/v2/spaces/#{space.guid}/auditors",
                    'apps_url'                    => "/v2/spaces/#{space.guid}/apps",
                    'routes_url'                  => "/v2/spaces/#{space.guid}/routes",
                    'domains_url'                 => "/v2/spaces/#{space.guid}/domains",
                    'service_instances_url'       => "/v2/spaces/#{space.guid}/service_instances",
                    'app_events_url'              => "/v2/spaces/#{space.guid}/app_events",
                    'events_url'                  => "/v2/spaces/#{space.guid}/events",
                    'security_groups_url'         => "/v2/spaces/#{space.guid}/security_groups"
                  }
                },
                'apps_url' => "/v2/routes/#{route.guid}/apps",
                'apps' => [
                  {
                    'metadata' =>                    {
                      'guid'       => process.guid,
                      'url'        => "/v2/apps/#{process.guid}",
                      'created_at' => iso8601,
                      'updated_at' => iso8601,
                    },
                    'entity' => {
                      'name'                       => process.name,
                      'production'                 => false,
                      'space_guid'                 => space.guid,
                      'stack_guid'                 => process.stack.guid,
                      'buildpack'                  => nil,
                      'detected_buildpack'         => nil,
                      'detected_buildpack_guid'    => nil,
                      'environment_json'           => nil,
                      'memory'                     => 1024,
                      'instances'                  => 1,
                      'disk_quota'                 => 1024,
                      'state'                      => 'STOPPED',
                      'version'                    => process.version,
                      'command'                    => nil,
                      'console'                    => false,
                      'debug'                      => nil,
                      'staging_task_id'            => nil,
                      'package_state'              => 'PENDING',
                      'health_check_type'          => 'port',
                      'health_check_timeout'       => nil,
                      'staging_failed_reason'      => nil,
                      'staging_failed_description' => nil,
                      'diego'                      => false,
                      'docker_image'               => nil,
                      'package_updated_at'         => iso8601,
                      'detected_start_command'     => '',
                      'enable_ssh'                 => true,
                      'docker_credentials_json'    => { 'redacted_message' => '[PRIVATE DATA HIDDEN]' },
                      'ports'                      => nil,
                      'space_url'                  => "/v2/spaces/#{space.guid}",
                      'stack_url'                  => "/v2/stacks/#{process.stack.guid}",
                      'routes_url'                 => "/v2/apps/#{process.guid}/routes",
                      'events_url'                 => "/v2/apps/#{process.guid}/events",
                      'service_bindings_url'       => "/v2/apps/#{process.guid}/service_bindings",
                      'route_mappings_url'         => "/v2/apps/#{process.guid}/route_mappings"
                    }
                  }
                ],
                'route_mappings_url' => "/v2/routes/#{route.guid}/route_mappings"
              }
            }]
          }
        )
      end
    end
  end

  describe 'GET /v2/routes/:guid' do
    let!(:route) { VCAP::CloudController::Route.make(domain: domain, space: space) }

    context 'with a shared domain' do
      let(:domain) { VCAP::CloudController::SharedDomain.make }

      it 'maps domain_url to the shared domains controller' do
        get "/v2/routes/#{route.guid}", nil, headers_for(user)
        expect(last_response.status).to eq(200)

        parsed_response = MultiJson.load(last_response.body)
        expect(parsed_response).to be_a_response_like(
          {
            'metadata' => {
              'guid'       => route.guid,
              'url'        => "/v2/routes/#{route.guid}",
              'created_at' => iso8601,
              'updated_at' => nil
            },
            'entity' => {
              'host'                  => route.host,
              'path'                  => '',
              'domain_guid'           => domain.guid,
              'space_guid'            => space.guid,
              'service_instance_guid' => nil,
              'port'                  => nil,
              'domain_url'            => "/v2/shared_domains/#{domain.guid}",
              'space_url'             => "/v2/spaces/#{space.guid}",
              'apps_url'              => "/v2/routes/#{route.guid}/apps",
              'route_mappings_url'    => "/v2/routes/#{route.guid}/route_mappings"
            }
          }
        )
      end
    end

    context 'with a private domain' do
      let(:domain) { VCAP::CloudController::PrivateDomain.make(router_group_guid: 'tcp-group', owning_organization: space.organization) }

      it 'maps domain_url to the shared domains controller' do
        get "/v2/routes/#{route.guid}", nil, headers_for(user)
        expect(last_response.status).to eq(200)

        parsed_response = MultiJson.load(last_response.body)
        expect(parsed_response['entity']['domain_url']).to eq("/v2/private_domains/#{domain.guid}")
      end
    end
  end
end
