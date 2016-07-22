require 'spec_helper'
require 'rspec_api_documentation/dsl'

RSpec.resource 'Apps', type: [:api, :legacy_api] do
  let(:admin_auth_header) { admin_headers['HTTP_AUTHORIZATION'] }
  let(:admin_buildpack) { VCAP::CloudController::Buildpack.make }
  let!(:apps) { 3.times { VCAP::CloudController::AppFactory.make } }
  let(:app_obj) { VCAP::CloudController::App.first }
  let(:guid) { app_obj.guid }

  authenticated_request

  shared_context 'guid_parameter' do
    parameter :guid, 'The guid of the App'
  end

  def self.request_fields(required)
    fields_info(required).reject { |f| [:detected_start_command].include?(f[:name]) }
  end

  # rubocop:disable Metrics/MethodLength
  def self.fields_info(required)
    [
      { name: :name, description: 'The name of the app.', custom_params: { required: required, example_values: ['my_super_app'] } },
      { name: :memory, description: 'The amount of memory each instance should have. In megabytes.', custom_params: { example_values: [1_024, 512] } },

      {
        name: :instances,
        description: 'The number of instances of the app to run. To ensure optimal availability, ensure there are at least 2 instances.',
        custom_params: { example_values: [2, 6, 10] }
      },

      { name: :disk_quota, description: 'The maximum amount of disk available to an instance of an app. In megabytes.', custom_params: { example_values: [1_204, 2_048] } },
      { name: :space_guid, description: 'The guid of the associated space.', custom_params: { required: required, example_values: [Sham.guid] } },
      { name: :stack_guid, description: 'The guid of the associated stack.', custom_params: { default: 'Uses the default system stack.', example_values: [Sham.guid] } },
      { name: :state, description: 'The current desired state of the app. One of STOPPED or STARTED.', custom_params: { default: 'STOPPED', valid_values: %w(STOPPED STARTED) } },
      { name: :command, description: "The command to start an app after it is staged, maximum length: 4096 (e.g. 'rails s -p $PORT' or 'java com.org.Server $PORT')." },

      {
        name: :buildpack,
        description: 'Buildpack to build the app. 3 options: a) Blank means autodetection; b) A Git Url pointing to a buildpack; c) Name of an installed buildpack.',
        custom_params: { default: '', example_values: ['', 'https://github.com/virtualstaticvoid/heroku-buildpack-r.git', 'an_example_installed_buildpack'] }
      },

      {
        name: :health_check_type,
        description: "Type of health check to perform. 'none' is deprecated and an alias to 'process'.",
        custom_params: { default: 'port', valid_values: ['port', 'process', 'none'] }
      },

      { name: :health_check_timeout, description: 'Timeout for health checking of an staged app when starting up' },

      { name: :diego, description: 'Use diego to stage and to run when available', custom_params: { default: false, valid_values: [true, false] } },
      {
        name: :enable_ssh,
        description: 'Enable SSHing into the app. Supported for Diego only.',
        custom_params: { default: 'false if SSH is disabled globally or on the space, true if enabled for both', valid_values: [true, false] }
      },
      {
        name: :detected_start_command,
        description: 'The command detected by the buildpack during staging.',
        custom_params: { default: '', example_values: ['rails s'] }
      },

      {
        name: :docker_image,
        description: 'Name of the Docker image containing the app. The "diego_docker" feature flag must be enabled in order to create Docker image apps.',
        custom_params: { default: nil, example_values: ['cloudfoundry/diego-docker-app', 'registry.example.com:5000/user/repository/tag'] }
      },

      {
        name: :docker_credentials_json,
        description: 'Docker credentials for pulling docker image.',
        custom_params: {
          default: {},
          experimental: true,
          example_values: [
            { 'docker_user' => 'user name', 'docker_password' => 's3cr3t', 'docker_email' => 'email@example.com', 'docker_login_server' => 'https://index.docker.io/v1/' }
          ]
        }
      },

      { name: :environment_json, description: 'Key/value pairs of all the environment variables to run in your app. Does not include any system or service variables.' },
      { name: :production, description: 'Deprecated.', custom_params: { deprecated: true, default: true, valid_values: [true, false] } },
      { name: :console, description: 'Open the console port for the app (at $CONSOLE_PORT).', custom_params: { deprecated: true, default: false, valid_values: [true, false] } },
      { name: :debug, description: 'Open the debug port for the app (at $DEBUG_PORT).', custom_params: { deprecated: true, default: false, valid_values: [true, false] } },

      {
        name: :staging_failed_reason,
        description: 'Reason for application staging failures',
        custom_params: { default: nil, example_values: ['StagingError', 'StagingTimeExpired'] }
      },

      {
        name: :staging_failed_description,
        description: 'Detailed description for the staging_failed_reason',
        custom_params: { default: nil, example_values: ['An app was not successfully detected by any available buildpack'] }
      },

      {
        name: :ports,
        description: 'Ports on which application may listen. Overwrites previously configured ports. Ports must be in range 1024-65535. Supported for Diego only.',
        custom_params: { experimental: true, example_values: [[5222, 8080], [1056]] }
      },
    ]
  end

  shared_context 'response_fields' do
    fields_info(false).each do |f|
      response_field f[:name], f[:description], f[:custom_params] || {}
    end
  end

  shared_context 'fields' do |opts|
    request_fields(opts[:required]).each do |f|
      field f[:name], f[:description], f[:custom_params] || {}
    end
  end

  describe 'Standard endpoints' do
    standard_model_delete_without_async :app
    standard_model_list :app, VCAP::CloudController::AppsController, response_fields: true
    standard_model_get :app, nested_associations: [:stack, :space], response_fields: true

    before do
      allow(VCAP::CloudController::Config.config).to receive(:[]).with(anything).and_call_original
      allow(VCAP::CloudController::Config.config).to receive(:[]).with(:diego).and_return(
        staging: 'optional',
        running: 'optional',
      )
    end

    def after_standard_model_delete(guid)
      event = VCAP::CloudController::Event.find(type: 'audit.app.delete-request', actee: guid)
      audited_event event
    end

    post '/v2/apps/' do
      include_context 'fields', required: true
      example 'Creating an App' do
        space_guid = VCAP::CloudController::Space.make.guid
        ports      = [1024, 2000]
        client.post '/v2/apps', MultiJson.dump(required_fields.merge(space_guid: space_guid, diego: true, ports: ports), pretty: true), headers
        expect(status).to eq(201)

        standard_entity_response parsed_response, :app

        app_guid = parsed_response['metadata']['guid']
        audited_event VCAP::CloudController::Event.find(type: 'audit.app.create', actee: app_guid)
      end

      example 'Creating a Docker App' do
        space_guid = VCAP::CloudController::Space.make.guid

        data = required_fields.merge(space_guid: space_guid, name: 'docker_app', docker_image: 'cloudfoundry/diego-docker-app', diego: true)
        client.post '/v2/apps', MultiJson.dump(data, pretty: true), headers
        expect(status).to eq(201)

        standard_entity_response parsed_response, :app
        expect(parsed_response['entity']['docker_image']).to eq('cloudfoundry/diego-docker-app:latest')
        expect(parsed_response['entity']['diego']).to be_truthy

        app_guid = parsed_response['metadata']['guid']
        audited_event VCAP::CloudController::Event.find(type: 'audit.app.create', actee: app_guid)
      end
    end

    put '/v2/apps/:guid' do
      include_context 'guid_parameter'
      include_context 'fields', required: false
      example 'Updating an App' do
        new_attributes = { name: 'new_name' }

        client.put "/v2/apps/#{guid}", MultiJson.dump(new_attributes, pretty: true), headers
        expect(status).to eq(201)
        standard_entity_response parsed_response, :app, name: 'new_name'
      end
    end
  end

  describe 'Nested endpoints' do
    include_context 'guid_parameter'

    describe 'Service Bindings' do
      let!(:service_instance) { VCAP::CloudController::ManagedServiceInstance.make(space: app_obj.space) }
      let(:associated_service_instance) { VCAP::CloudController::ManagedServiceInstance.make(space: app_obj.space) }

      let(:service_binding) { VCAP::CloudController::ServiceBinding.make(service_instance: service_instance) }
      let(:service_binding_guid) { service_binding.guid }
      let!(:associated_service_binding) { VCAP::CloudController::ServiceBinding.make(app: app_obj, service_instance: associated_service_instance) }
      let(:associated_service_binding_guid) { associated_service_binding.guid }

      before do
        service_broker = associated_service_binding.service.service_broker
        instance_guid  = associated_service_instance.guid
        binding_guid   = associated_service_binding.guid
        uri            = URI(service_broker.broker_url)
        broker_url     = uri.host + uri.path
        broker_auth    = "#{service_broker.auth_username}:#{service_broker.auth_password}"
        stub_request(
          :delete,
          %r{https://#{broker_auth}@#{broker_url}/v2/service_instances/#{instance_guid}/service_bindings/#{binding_guid}}).
          to_return(status: 200, body: '{}')
      end

      standard_model_list :service_binding, VCAP::CloudController::ServiceBindingsController, outer_model: :app

      context 'has service binding guid param' do
        parameter :service_binding_guid, 'The guid of the service binding'
        nested_model_remove :service_binding, :app
      end
    end

    describe 'Routes' do
      before do
        app_obj.add_route(associated_route)
      end
      let!(:route) { VCAP::CloudController::Route.make(space: app_obj.space) }
      let(:route_guid) { route.guid }
      let(:associated_route) { VCAP::CloudController::Route.make(space: app_obj.space) }
      let(:associated_route_guid) { associated_route.guid }

      standard_model_list :route, VCAP::CloudController::RoutesController, outer_model: :app, exclude_parameters: ['organization_guid']

      context 'has route guid param' do
        parameter :route_guid, 'The guid of the route'

        nested_model_associate :route, :app
        nested_model_remove :route, :app
      end
    end
  end

  get '/v2/apps/:guid/env' do
    include_context 'guid_parameter'
    let(:app_obj) { VCAP::CloudController::AppFactory.make(detected_buildpack: 'buildpack-name', environment_json: { env_var: 'env_val' }) }

    before do
      group = VCAP::CloudController::EnvironmentVariableGroup.staging
      group.environment_json = { STAGING_ENV: 'staging_value' }
      group.save

      group = VCAP::CloudController::EnvironmentVariableGroup.running
      group.environment_json = { RUNNING_ENV: 'running_value' }
      group.save
    end

    example 'Get the env for an App' do
      explanation <<-EOD
        Get the environment variables for an App using the app guid. Restricted to SpaceDeveloper role.
      EOD

      client.get "/v2/apps/#{app_obj.guid}/env", {}, headers
      expect(status).to eq(200)

      expect(parsed_response).to have_key('staging_env_json')
      expect(parsed_response['staging_env_json']['STAGING_ENV']).to eq('staging_value')

      expect(parsed_response).to have_key('running_env_json')
      expect(parsed_response['running_env_json']['RUNNING_ENV']).to eq('running_value')

      expect(parsed_response).to have_key('system_env_json')
      expect(parsed_response).to have_key('environment_json')
      expect(parsed_response).to have_key('application_env_json')
    end
  end

  get '/v2/apps/:guid/instances' do
    include_context 'guid_parameter'

    let(:app_obj) { VCAP::CloudController::AppFactory.make(state: 'STARTED', package_hash: 'abc', package_state: 'STAGED') }

    example 'Get the instance information for a STARTED App' do
      explanation <<-EOD
        Get status for each instance of an App using the app guid. Note: Provided example response is for apps running on Diego.

        For apps running on DEAs, instance information will appear as follows:
        {
          "0": {
            "state": "RUNNING",
            "since": 1403140717.984577,
            "debug_ip": null,
            "debug_port": null,
            "console_ip": null,
            "console_port": null
          }
        }.
      EOD

      instances = {
        0 => {
          state:        'RUNNING',
          since:        1403140717.984577,
          uptime:       2405
        },
        1 => {
          state:        'STARTING',
          since:        3625363939.984577,
          uptime:       1394
        },
        2 => {
          state:        'CRASHED',
          since:        2514251828.984577,
          uptime:       283
        },
        3 => {
          state:        'DOWN',
          uptime:       9172
        }
      }

      instances_reporters = double(:instances_reporters)
      allow(CloudController::DependencyLocator.instance).to receive(:instances_reporters).and_return(instances_reporters)
      allow(instances_reporters).to receive(:all_instances_for_app).and_return(instances)

      client.get "/v2/apps/#{app_obj.guid}/instances", {}, headers
      expect(status).to eq(200)
    end
  end

  delete '/v2/apps/:guid/instances/:index' do
    include_context 'guid_parameter'
    parameter :index, 'The index of the App Instance to terminate'

    let(:app_obj) { VCAP::CloudController::AppFactory.make(state: 'STARTED', instances: 2) }

    example 'Terminate the running App Instance at the given index' do
      allow(VCAP::CloudController::Dea::Client).to receive(:stop_indices)
      client.delete "/v2/apps/#{app_obj.guid}/instances/0", {}, headers
      expect(status).to eq(204)
    end
  end

  get '/v2/apps/:guid/stats' do
    include_context 'guid_parameter'

    let(:app_obj) { VCAP::CloudController::AppFactory.make(state: 'STARTED', package_hash: 'abc') }

    example 'Get detailed stats for a STARTED App' do
      explanation <<-EOD
        Get status for each instance of an App using the app guid.
      EOD

      stats = {
        0 => {
          state: 'RUNNING',
          stats: {
            usage: {
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
            fds_quota:  16384
          }
        }
      }

      instances_reporters = double(:instances_reporters)
      allow(CloudController::DependencyLocator.instance).to receive(:instances_reporters).and_return(instances_reporters)
      allow(instances_reporters).to receive(:stats_for_app).and_return(stats)

      client.get "/v2/apps/#{app_obj.guid}/stats", {}, headers
      expect(status).to eq(200)
    end
  end
end
