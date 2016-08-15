require 'spec_helper'

RSpec.describe 'Apps' do
  let(:user) { VCAP::CloudController::User.make }
  let(:space) { VCAP::CloudController::Space.make }

  before do
    space.organization.add_user(user)
    space.add_developer(user)
  end

  describe 'GET /v2/apps' do
    let!(:process) {
      VCAP::CloudController::AppFactory.make(
        space:                   space,
        environment_json:        { 'RAILS_ENV' => 'staging' },
        command:                 'hello_world',
        docker_credentials_json: { 'docker_user' => 'bob', 'docker_password' => 'password', 'docker_email' => 'blah@blah.com' }
      )
    }

    it 'lists all apps' do
      get '/v2/apps', nil, headers_for(user)

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
              'guid'       => process.guid,
              'url'        => "/v2/apps/#{process.guid}",
              'created_at' => iso8601,
              'updated_at' => iso8601
            },
            'entity' => {
              'name'                       => process.name,
              'production'                 => false,
              'space_guid'                 => space.guid,
              'stack_guid'                 => process.stack.guid,
              'buildpack'                  => nil,
              'detected_buildpack'         => nil,
              'detected_buildpack_guid'    => nil,
              'environment_json'           => { 'RAILS_ENV' => 'staging' },
              'memory'                     => 1024,
              'instances'                  => 1,
              'disk_quota'                 => 1024,
              'state'                      => 'STOPPED',
              'version'                    => process.version,
              'command'                    => 'hello_world',
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
              'docker_credentials_json'    => {
                'redacted_message' => '[PRIVATE DATA HIDDEN]'
              },
              'ports'                      => nil,
              'space_url'                  => "/v2/spaces/#{space.guid}",
              'stack_url'                  => "/v2/stacks/#{process.stack.guid}",
              'routes_url'                 => "/v2/apps/#{process.guid}/routes",
              'events_url'                 => "/v2/apps/#{process.guid}/events",
              'service_bindings_url'       => "/v2/apps/#{process.guid}/service_bindings",
              'route_mappings_url'         => "/v2/apps/#{process.guid}/route_mappings"
            }
          }]
        }
      )
    end

    context 'with inline-relations-depth' do
      it 'includes related records' do
        get '/v2/apps?inline-relations-depth=1', nil, headers_for(user)

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
                'guid'       => process.guid,
                'url'        => "/v2/apps/#{process.guid}",
                'created_at' => iso8601,
                'updated_at' => iso8601
              },
              'entity' => {
                'name'                       => process.name,
                'production'                 => false,
                'space_guid'                 => space.guid,
                'stack_guid'                 => process.stack.guid,
                'buildpack'                  => nil,
                'detected_buildpack'         => nil,
                'detected_buildpack_guid'    => nil,
                'environment_json'           => { 'RAILS_ENV' => 'staging' },
                'memory'                     => 1024,
                'instances'                  => 1,
                'disk_quota'                 => 1024,
                'state'                      => 'STOPPED',
                'version'                    => process.version,
                'command'                    => 'hello_world',
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
                'docker_credentials_json'    => {
                  'redacted_message' => '[PRIVATE DATA HIDDEN]'
                },
                'ports'                      => nil,
                'space_url'                  => "/v2/spaces/#{space.guid}",
                'space'                      => {
                  'metadata' => {
                    'guid'       => space.guid,
                    'url'        => "/v2/spaces/#{space.guid}",
                    'created_at' => iso8601,
                    'updated_at' => nil
                  },
                  'entity' => {
                    'name'                        => space.name,
                    'organization_guid'           => space.organization_guid,
                    'space_quota_definition_guid' => nil,
                    'allow_ssh'                   => true,
                    'organization_url'            => "/v2/organizations/#{space.organization_guid}",
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
                'stack_url'                  => "/v2/stacks/#{process.stack.guid}",
                'stack'                      => {
                  'metadata' => {
                    'guid'       => process.stack.guid,
                    'url'        => "/v2/stacks/#{process.stack.guid}",
                    'created_at' => iso8601,
                    'updated_at' => nil
                  },
                  'entity' => {
                    'name'        => process.stack.name,
                    'description' => process.stack.description
                  }
                },
                'routes_url'                 => "/v2/apps/#{process.guid}/routes",
                'routes'                     => [],
                'events_url'                 => "/v2/apps/#{process.guid}/events",
                'service_bindings_url'       => "/v2/apps/#{process.guid}/service_bindings",
                'service_bindings'           => [],
                'route_mappings_url'         => "/v2/apps/#{process.guid}/route_mappings"
              }
            }]
          }
        )
      end
    end
  end

  describe 'GET /v2/apps/:guid' do
    let!(:process) {
      VCAP::CloudController::AppFactory.make(
        space:                   space,
        name:                    'app-name',
        docker_credentials_json: { 'docker_user' => 'bob', 'docker_password' => 'password', 'docker_email' => 'blah@blah.com' },
        command:                 'app-command'
      )
    }

    it 'displays the app' do
      get "/v2/apps/#{process.guid}", nil, headers_for(user)
      expect(last_response.status).to eq(200)

      parsed_response = MultiJson.load(last_response.body)
      expect(parsed_response).to be_a_response_like(
        {
          'metadata' => {
            'guid'       => process.guid,
            'url'        => "/v2/apps/#{process.guid}",
            'created_at' => iso8601,
            'updated_at' => iso8601
          },
          'entity' => {
            'name'                       => 'app-name',
            'production'                 => false,
            'space_guid'                 => process.space.guid,
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
            'command'                    => 'app-command',
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
            'docker_credentials_json'    => {
              'redacted_message' => '[PRIVATE DATA HIDDEN]'
            },
            'ports'                      => nil,
            'space_url'                  => "/v2/spaces/#{process.space.guid}",
            'stack_url'                  => "/v2/stacks/#{process.stack.guid}",
            'routes_url'                 => "/v2/apps/#{process.guid}/routes",
            'events_url'                 => "/v2/apps/#{process.guid}/events",
            'service_bindings_url'       => "/v2/apps/#{process.guid}/service_bindings",
            'route_mappings_url'         => "/v2/apps/#{process.guid}/route_mappings"
          }
        }
      )
    end
  end

  describe 'POST /v2/apps' do
    it 'creates an app' do
      post_params = MultiJson.dump({
        name:                    'maria',
        space_guid:              space.guid,
        detected_start_command:  'argh',
        docker_credentials_json: { 'docker_user' => 'bob', 'docker_password' => 'password', 'docker_email' => 'blah@blah.com' }
      })

      post '/v2/apps', post_params, headers_for(user)

      process = VCAP::CloudController::App.last
      expect(last_response.status).to eq(201)
      expect(MultiJson.load(last_response.body)).to be_a_response_like(
        {
          'metadata' => {
            'guid'       => process.guid,
            'url'        => "/v2/apps/#{process.guid}",
            'created_at' => iso8601,
            'updated_at' => nil
          },
          'entity' => {
            'name'                       => 'maria',
            'production'                 => false,
            'space_guid'                 => space.guid,
            'stack_guid'                 => process.stack.guid,
            'buildpack'                  => nil,
            'detected_buildpack'         => nil,
            'detected_buildpack_guid'    => nil,
            'environment_json'           => {

            },
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
            'package_updated_at'         => nil,
            'detected_start_command'     => '',
            'enable_ssh'                 => true,
            'docker_credentials_json'    => {
              'redacted_message' => '[PRIVATE DATA HIDDEN]'
            },
            'ports'                      => nil,
            'space_url'                  => "/v2/spaces/#{space.guid}",
            'stack_url'                  => "/v2/stacks/#{process.stack.guid}",
            'routes_url'                 => "/v2/apps/#{process.guid}/routes",
            'events_url'                 => "/v2/apps/#{process.guid}/events",
            'service_bindings_url'       => "/v2/apps/#{process.guid}/service_bindings",
            'route_mappings_url'         => "/v2/apps/#{process.guid}/route_mappings"
          }
        }
      )
    end
  end

  describe 'PUT /v2/apps/:guid' do
    let!(:process) {
      VCAP::CloudController::AppFactory.make(
        space:                   space,
        name:                    'mario',
        environment_json:        { 'RAILS_ENV' => 'staging' },
        command:                 'hello_world',
        docker_credentials_json: { 'docker_user' => 'bob', 'docker_password' => 'password', 'docker_email' => 'blah@blah.com' }
      )
    }

    it 'updates an app' do
      update_params = MultiJson.dump({
        name:                   'maria',
        environment_json:       { 'RAILS_ENV' => 'production' },
        state:                  'STARTED',
        detected_start_command: 'argh'
      })

      put "/v2/apps/#{process.guid}", update_params, headers_for(user)

      process.reload
      expect(last_response.status).to eq(201)
      expect(MultiJson.load(last_response.body)).to be_a_response_like(
        {
          'metadata' => {
            'guid'       => process.guid,
            'url'        => "/v2/apps/#{process.guid}",
            'created_at' => iso8601,
            'updated_at' => iso8601
          },
          'entity' => {
            'name'                       => 'maria',
            'production'                 => false,
            'space_guid'                 => space.guid,
            'stack_guid'                 => process.stack.guid,
            'buildpack'                  => nil,
            'detected_buildpack'         => nil,
            'detected_buildpack_guid'    => nil,
            'environment_json'           => {
              'RAILS_ENV' => 'production'
            },
            'memory'                     => 1024,
            'instances'                  => 1,
            'disk_quota'                 => 1024,
            'state'                      => 'STARTED',
            'version'                    => process.version,
            'command'                    => 'hello_world',
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
            'docker_credentials_json'    => {
              'redacted_message' => '[PRIVATE DATA HIDDEN]'
            },
            'ports'                      => nil,
            'space_url'                  => "/v2/spaces/#{space.guid}",
            'stack_url'                  => "/v2/stacks/#{process.stack.guid}",
            'routes_url'                 => "/v2/apps/#{process.guid}/routes",
            'events_url'                 => "/v2/apps/#{process.guid}/events",
            'service_bindings_url'       => "/v2/apps/#{process.guid}/service_bindings",
            'route_mappings_url'         => "/v2/apps/#{process.guid}/route_mappings"
          }
        }
      )
    end
  end

  describe 'DELETE /v2/apps/:guid' do
    let!(:process) { VCAP::CloudController::AppFactory.make(space: space) }

    it 'deletes the specified app' do
      delete "/v2/apps/#{process.guid}", nil, headers_for(user)

      expect(last_response.status).to eq(204)

      get "/v2/apps/#{process.guid}", nil, headers_for(user)
      parsed_response = MultiJson.load(last_response.body)

      expect(parsed_response['error_code']).to eq 'CF-AppNotFound'
    end
  end

  describe 'GET /v2/apps/:guid/summary' do
    let!(:process) { VCAP::CloudController::AppFactory.make(space: space, name: 'woo') }

    it 'gives a summary of the specified app' do
      private_domains = process.space.organization.private_domains
      shared_domains  = VCAP::CloudController::SharedDomain.all.collect do |domain|
        { 'guid'              => domain.guid,
          'name'              => domain.name,
          'router_group_guid' => domain.router_group_guid,
          'router_group_type' => domain.router_group_type,
        }
      end
      avail_domains = private_domains + shared_domains

      get "/v2/apps/#{process.guid}/summary", nil, headers_for(user)

      expect(last_response.status).to eq(200)
      expect(MultiJson.load(last_response.body)).to be_a_response_like(
        {
          'guid'                       => process.guid,
          'name'                       => 'woo',
          'routes'                     => [],
          'running_instances'          => 0,
          'services'                   => [],
          'available_domains'          => avail_domains,
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
          'ports'                      => nil
        })
    end
  end

  describe 'GET /v2/apps/:guid/env' do
    let(:process) do
      VCAP::CloudController::App.make(
        space:              space,
        name:               'potato',
        detected_buildpack: 'buildpack-name',
        environment_json:   { env_var: 'env_val' },
        memory:             1024,
        disk_quota:         1024,
      )
    end

    before do
      VCAP::CloudController::RouteMapping.make(
        app:   process,
        route: VCAP::CloudController::Route.make(space: space, host: 'potato', domain: VCAP::CloudController::SharedDomain.first)
      )

      group                  = VCAP::CloudController::EnvironmentVariableGroup.staging
      group.environment_json = { STAGING_ENV: 'staging_value' }
      group.save

      group                  = VCAP::CloudController::EnvironmentVariableGroup.running
      group.environment_json = { RUNNING_ENV: 'running_value' }
      group.save
    end

    it 'shows the apps env' do
      get "/v2/apps/#{process.guid}/env", nil, headers_for(user)
      expect(last_response.status).to eq(200)

      expect(MultiJson.load(last_response.body)).to be_a_response_like(
        {
          'staging_env_json'     => { 'STAGING_ENV' => 'staging_value' },
          'running_env_json'     => { 'RUNNING_ENV' => 'running_value' },
          'environment_json'     => { 'env_var' => 'env_val' },
          'system_env_json'      => { 'VCAP_SERVICES' => {} },
          'application_env_json' => {
            'VCAP_APPLICATION' => {
              'limits' => {
                'fds'  => 16384,
                'mem'  => 1024,
                'disk' => 1024
              },
              'application_name'    => 'potato',
              'application_uris'    => ["potato.#{VCAP::CloudController::SharedDomain.first.name}"],
              'name'                => 'potato',
              'space_name'          => space.name,
              'space_id'            => space.guid,
              'uris'                => ["potato.#{VCAP::CloudController::SharedDomain.first.name}"],
              'users'               => nil,
              'application_id'      => process.guid,
              'version'             => process.version,
              'application_version' => process.version
            }
          }
        }
      )
      expect(parsed_response['application_env_json']['VCAP_APPLICATION']['version']).not_to be_nil
      expect(parsed_response['application_env_json']['VCAP_APPLICATION']['application_version']).not_to be_nil
    end
  end

  describe 'GET /v2/apps/:guid/stats' do
    let(:process) { VCAP::CloudController::AppFactory.make(state: 'STARTED', space: space) }
    let(:instances_reporters) { instance_double(VCAP::CloudController::Diego::InstancesReporter) }
    let(:instances_reporter_response) do
      {
        0 => {
          state: 'RUNNING',
          stats: {
            usage:      {
              disk: 66392064,
              mem:  29880320,
              cpu:  0.13511219703079957,
              time: '2014-06-19 22:37:58 +0000'
            },
            name:       'app_name',
            uris:       [
              'app_name.example.com'
            ],
            host:       '10.0.0.1',
            port:       61035,
            uptime:     65007,
            mem_quota:  536870912,
            disk_quota: 1073741824,
            fds_quota:  16384,
            net_info:   {
              address: '10.244.16.10',
              ports:   [
                {
                  container_port: 8080,
                  host_port:      60002
                },
                {
                  container_port: 2222,
                  host_port:      60003
                }
              ]
            }
          }
        }
      }
    end

    before do
      allow(CloudController::DependencyLocator.instance).to receive(:instances_reporters).and_return(instances_reporters)
      allow(instances_reporters).to receive(:stats_for_app).and_return(instances_reporter_response)
    end

    it 'displays the stats' do
      get "/v2/apps/#{process.guid}/stats", nil, headers_for(user)

      expect(last_response.status).to eq(200)
      parsed_response = MultiJson.load(last_response.body)
      expect(parsed_response).to be_a_response_like(
        {
          '0' => {
            'state' => 'RUNNING',
            'stats' => {
              'name'       => 'app_name',
              'uris'       => ['app_name.example.com'],
              'host'       => '10.0.0.1',
              'port'       => 61035,
              'uptime'     => 65007,
              'mem_quota'  => 536870912,
              'disk_quota' => 1073741824,
              'fds_quota'  => 16384,
              'usage'      => {
                'time' => '2014-06-19 22:37:58 +0000',
                'cpu'  => 0.13511219703079957,
                'mem'  => 29880320,
                'disk' => 66392064
              }
            }
          }
        }
      )
    end
  end

  describe 'GET /v2/apps/:guid/instances' do
    let!(:process) { VCAP::CloudController::AppFactory.make(diego: true, space: space, state: 'STARTED', package_state: 'STAGED', instances: 2) }
    let(:tps_url) { "http://tps.service.cf.internal:1518/v1/actual_lrps/#{process.guid}-#{process.version}" }
    let(:instances) { [
      { process_guid: process.guid, instance_guid: 'instance-A', index: 0, state: 'RUNNING', uptime: 0 },
      { process_guid: process.guid, instance_guid: 'instance-A', index: 1, state: 'RUNNING', uptime: 0 }
    ]
    }

    before do
      stub_request(:get, tps_url).to_return(status: 200, body: instances.to_json)
    end

    it 'gets the instance information for a started app' do
      get "/v2/apps/#{process.guid}/instances", nil, headers_for(user)
      parsed_response = MultiJson.load(last_response.body)

      expect(last_response.status).to eq(200)
      expect(parsed_response).to be_a_response_like(
        {
          '0' => {
            'state' => 'RUNNING', 'uptime' => 0, 'since' => nil
          },
          '1' => {
            'state' => 'RUNNING', 'uptime' => 0, 'since' => nil
          }
        }
      )
    end
  end

  describe 'DELETE /v2/apps/:guid/instances/:index' do
    let(:process) { VCAP::CloudController::AppFactory.make(space: space, instances: 2, diego: true) }
    let(:stop_url) { %r{http://nsync.service.cf.internal:8787/v1/apps/#{process.guid}.+/index/0} }

    before do
      stub_request(:delete, stop_url).to_return(status: 202)
    end

    it 'stops the instance' do
      delete "/v2/apps/#{process.guid}/instances/0", nil, headers_for(user)

      expect(last_response.status).to eq(204)
      expect(a_request(:delete, stop_url)).to have_been_made
    end
  end

  describe 'POST /v2/apps/:guid/restage' do
    let(:process) do
      VCAP::CloudController::AppFactory.make(
        name:          'maria',
        space:         space,
        package_state: 'STAGED',
        diego:         true
      )
    end

    it 'restages the app' do
      post "/v2/apps/#{process.guid}/restage", nil, headers_for(user)

      parsed_response = MultiJson.load(last_response.body)

      process.reload
      expect(last_response.status).to eq(201)
      expect(parsed_response).to be_a_response_like(
        {
          'metadata' => {
            'guid'       => process.guid,
            'url'        => "/v2/apps/#{process.guid}",
            'created_at' => iso8601,
            'updated_at' => iso8601
          },
          'entity' => {
            'name'                       => 'maria',
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
            'state'                      => 'STARTED',
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
            'diego'                      => true,
            'docker_image'               => nil,
            'package_updated_at'         => iso8601,
            'detected_start_command'     => '',
            'enable_ssh'                 => true,
            'docker_credentials_json'    => {
              'redacted_message' => '[PRIVATE DATA HIDDEN]'
            },
            'ports' => []
          }
        }
      )
    end
  end

  describe 'PUT /v2/apps/:guid/bits' do
    let(:process) { VCAP::CloudController::AppFactory.make(space: space) }
    let(:tmpdir) { Dir.mktmpdir }
    let(:valid_zip) do
      zip_name = File.join(tmpdir, 'file.zip')
      TestZip.create(zip_name, 1, 1024)
      zip_file = File.new(zip_name)
      Rack::Test::UploadedFile.new(zip_file)
    end

    it 'uploads the application bits' do
      upload_params = {
        application: valid_zip,
        resources:   [
          { fn: 'path/to/content.txt', size: 123, sha1: 'b907173290db6a155949ab4dc9b2d019dea0c901' },
          { fn: 'path/to/code.jar', size: 123, sha1: 'ff84f89760317996b9dd180ab996b079f418396f' }
        ].to_json,
      }

      put "/v2/apps/#{process.guid}/bits?async=true", upload_params, headers_for(user)

      parsed_response = MultiJson.load(last_response.body)

      expect(last_response.status).to eq 201
      expect(parsed_response['entity']['status']).to eq 'queued'
    end
  end

  describe 'POST /v2/apps/:guid/copy_bits' do
    let!(:source_process) { VCAP::CloudController::AppFactory.make(space: space) }
    let!(:destination_process) { VCAP::CloudController::AppFactory.make(space: space) }

    it 'queues a job to copy the bits' do
      post "/v2/apps/#{destination_process.guid}/copy_bits", MultiJson.dump({ source_app_guid: source_process.guid }), headers_for(user)

      expect(last_response.status).to eq(201)
      parsed_response = MultiJson.load(last_response.body)
      expect(parsed_response['entity']['status']).to eq 'queued'
    end
  end

  describe 'GET /v2/apps/:guid/download' do
    let(:process) { VCAP::CloudController::AppFactory.make(space: space) }
    let(:tmpdir) { Dir.mktmpdir }
    let(:valid_zip) do
      zip_name = File.join(tmpdir, 'file.zip')
      TestZip.create(zip_name, 1, 1024)
      zip_file = File.new(zip_name)
      Rack::Test::UploadedFile.new(zip_file)
    end

    before do
      upload_params = {
        application: valid_zip,
        resources:   [{ fn: 'a/b/c', size: 1, sha1: 'sha' }].to_json
      }
      put "/v2/apps/#{process.guid}/bits", upload_params, headers_for(user)
    end

    it 'redirects to a blobstore url' do
      get "/v2/apps/#{process.guid}/download", nil, headers_for(user)

      expect(last_response.headers['Location']).to include('cc-packages.s3.amazonaws.com')
      expect(last_response.status).to eq(302)
    end
  end

  describe 'GET /v2/apps/:guid/droplet/download' do
    let(:process) { VCAP::CloudController::AppFactory.make(space: space) }
    let(:blobstore) { CloudController::DependencyLocator.instance.droplet_blobstore }

    before do
      droplet_file = Tempfile.new(process.guid)
      droplet_file.write('droplet contents')
      droplet_file.close

      droplet = CloudController::DropletUploader.new(process, blobstore)
      droplet.upload(droplet_file.path)
    end

    it 'redirects to a blobstore to download the droplet' do
      get "/v2/apps/#{process.guid}/droplet/download", nil, headers_for(user)
      expect(last_response.status).to eq(302)
      expect(last_response.headers['Location']).to include('cc-droplets.s3.amazonaws.com')
    end
  end

  describe 'GET /v2/apps/:guid/service_bindings' do
    let!(:process) { VCAP::CloudController::AppFactory.make(space: space) }
    let!(:service_instance) { VCAP::CloudController::ManagedServiceInstance.make(space: process.space) }
    let!(:service_binding) do
      VCAP::CloudController::ServiceBinding.make(
        service_instance: service_instance,
        app:              process,
        credentials:      { 'creds-key' => 'creds-val' }
      )
    end

    before do
      service_instance.add_service_binding(service_binding)
    end

    it 'lists the service bindings associated with the app' do
      get "/v2/apps/#{process.guid}/service_bindings", nil, headers_for(user)

      parsed_response = MultiJson.load(last_response.body)

      expect(last_response.status).to eq 200
      expect(parsed_response).to be_a_response_like(
        {
          'total_results' => 1,
          'total_pages'   => 1,
          'prev_url'      => nil,
          'next_url'      => nil,
          'resources'     => [
            {
              'metadata' => {
                'guid'       => service_binding.guid,
                'url'        => "/v2/service_bindings/#{service_binding.guid}",
                'created_at' => iso8601,
                'updated_at' => iso8601
              },
              'entity' => {
                'app_guid'              => process.guid,
                'service_instance_guid' => service_instance.guid,
                'credentials'           => { 'creds-key' => 'creds-val' },
                'binding_options'       => {},
                'gateway_data'          => nil,
                'gateway_name'          => '',
                'syslog_drain_url'      => nil,
                'volume_mounts'         => [],
                'app_url'               => "/v2/apps/#{process.guid}",
                'service_instance_url'  => "/v2/service_instances/#{service_instance.guid}"
              }
            }
          ]
        }
      )
    end
  end

  describe 'DELETE /v2/apps/:guid/service_binding/:guid' do
    let!(:process) { VCAP::CloudController::AppFactory.make(space: space) }
    let!(:service_instance) { VCAP::CloudController::ManagedServiceInstance.make(space: process.space) }
    let!(:service_binding) { VCAP::CloudController::ServiceBinding.make(service_instance: service_instance, app: process) }

    before do
      service_instance.add_service_binding(service_binding)

      service_broker = service_binding.service.service_broker
      uri            = URI(service_broker.broker_url)
      broker_url     = uri.host + uri.path
      broker_auth    = "#{service_broker.auth_username}:#{service_broker.auth_password}"
      stub_request(
        :delete,
        %r{https://#{broker_auth}@#{broker_url}/v2/service_instances/#{service_instance.guid}/service_bindings/#{service_binding.guid}}).
        to_return(status: 200, body: '{}')
    end

    it 'deletes the specified service binding' do
      delete "/v2/apps/#{process.guid}/service_bindings/#{service_binding.guid}", nil, headers_for(user)

      expect(last_response.status).to eq 204
      expect(service_binding.exists?).to be_falsey
    end
  end

  describe 'GET /v2/apps/:guid/routes' do
    let!(:process) { VCAP::CloudController::AppFactory.make(space: space) }
    let!(:route) { VCAP::CloudController::Route.make(space: space, host: 'youdontknowme') }
    let!(:route_mapping) { VCAP::CloudController::RouteMapping.make(app: process, route: route) }

    it 'shows the routes associated with an app' do
      get "/v2/apps/#{process.guid}/routes", nil, headers_for(user)

      expect(last_response.status).to eq(200)
      expect(MultiJson.load(last_response.body)).to be_a_response_like(
        {
          'total_results' => 1,
          'total_pages'   => 1,
          'prev_url'      => nil,
          'next_url'      => nil,
          'resources'     => [
            {
              'metadata' => {
                'guid'       => route.guid,
                'url'        => "/v2/routes/#{route.guid}",
                'created_at' => iso8601,
                'updated_at' => nil
              },
              'entity' => {
                'host'                  => 'youdontknowme',
                'path'                  => '',
                'domain_guid'           => route.domain_guid,
                'space_guid'            => space.guid,
                'service_instance_guid' => nil,
                'port'                  => nil,
                'domain_url'            => "/v2/private_domains/#{route.domain_guid}",
                'space_url'             => "/v2/spaces/#{space.guid}",
                'apps_url'              => "/v2/routes/#{route.guid}/apps",
                'route_mappings_url'    => "/v2/routes/#{route.guid}/route_mappings"
              }
            }
          ]
        }
      )
    end
  end

  describe 'PUT /v2/apps/:guid/routes/:route_guid' do
    let!(:process) { VCAP::CloudController::AppFactory.make(space: space) }
    let!(:route) { VCAP::CloudController::Route.make(space: space) }

    it 'associates an app and a route' do
      put "/v2/apps/#{process.guid}/routes/#{route.guid}", nil, headers_for(user)
      process.reload

      expect(last_response.status).to eq(201)
      parsed_response = MultiJson.load(last_response.body)
      expect(parsed_response).to be_a_response_like(
        {
          'metadata' =>
            { 'guid'       => process.guid,
              'url'        => "/v2/apps/#{process.guid}",
              'created_at' => iso8601,
              'updated_at' => iso8601,
            },
          'entity'   => {
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
      )

      expect(process.routes).to include(route)
      route_mapping = VCAP::CloudController::RouteMapping.find(app: process, route: route)
      expect(route_mapping).not_to be_nil
    end
  end

  describe 'DELETE /v2/apps/:guid/routes/:guid' do
    let!(:process) { VCAP::CloudController::AppFactory.make(space: space) }
    let!(:route1) { VCAP::CloudController::Route.make(space: space, host: 'youdontknowme') }
    let!(:route2) { VCAP::CloudController::Route.make(space: space, host: 'andyouneverwill') }
    let!(:route_mapping1) { VCAP::CloudController::RouteMapping.make(app: process, route: route1) }
    let!(:route_mapping2) { VCAP::CloudController::RouteMapping.make(app: process, route: route2) }

    it 'removes the associated route' do
      expect(process.routes).to include(route1)
      expect(route_mapping1.exists?).to be_truthy

      delete "/v2/apps/#{process.guid}/routes/#{route1.guid}", nil, headers_for(user)

      expect(last_response.status).to eq(204)
      expect(process.reload.routes).not_to include(route1)
      expect(route_mapping1.exists?).to be_falsey
    end
  end

  describe 'GET /v2/apps/:guid/route_mappings' do
    let!(:process) { VCAP::CloudController::AppFactory.make(space: space) }
    let!(:route) { VCAP::CloudController::Route.make(space: space) }
    let!(:route_mapping) { VCAP::CloudController::RouteMapping.make(app: process, route: route) }

    it 'lists associated route_mappings' do
      get "/v2/apps/#{process.guid}/route_mappings", nil, headers_for(user)
      parsed_response = MultiJson.load(last_response.body)

      expect(last_response.status).to eq(200)
      expect(parsed_response).to be_a_response_like(
        {
          'total_results' => 1,
          'total_pages'   => 1,
          'prev_url'      => nil,
          'next_url'      => nil,
          'resources'     => [
            {
              'metadata' => {
                'guid'       => route_mapping.guid,
                'url'        => "/v2/route_mappings/#{route_mapping.guid}",
                'created_at' => iso8601,
                'updated_at' => nil
              },
              'entity' => {
                'app_port'   => nil,
                'app_guid'   => process.guid,
                'route_guid' => route.guid,
                'app_url'    => "/v2/apps/#{process.guid}",
                'route_url'  => "/v2/routes/#{route.guid}"
              }
            }
          ]
        }
      )
    end
  end
end
