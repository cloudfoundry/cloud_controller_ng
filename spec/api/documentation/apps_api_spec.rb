require 'spec_helper'
require 'rspec_api_documentation/dsl'

resource 'Apps', type: [:api, :legacy_api] do
  let(:admin_auth_header) { admin_headers['HTTP_AUTHORIZATION'] }
  let(:admin_buildpack) { VCAP::CloudController::Buildpack.make }
  let!(:apps) { 3.times { VCAP::CloudController::AppFactory.make } }
  let(:app_obj) { VCAP::CloudController::App.first }
  let(:guid) { app_obj.guid }

  authenticated_request

  shared_context 'guid_parameter' do
    parameter :guid, 'The guid of the App'
  end

  shared_context 'fields' do |opts|
    field :name, 'The name of the app.', required: opts[:required], example_values: ['my_super_app']
    field :memory, 'The amount of memory each instance should have. In megabytes.', example_values: [1_024, 512]

    field :instances,
      'The number of instances of the app to run. To ensure optimal availability, ensure there are at least 2 instances.',
      example_values: [2, 6, 10]

    field :disk_quota, 'The maximum amount of disk available to an instance of an app. In megabytes.', example_values: [1_204, 2_048]
    field :space_guid, 'The guid of the associated space.', required: opts[:required], example_values: [Sham.guid]
    field :stack_guid, 'The guid of the associated stack.', default: 'Uses the default system stack.', example_values: [Sham.guid]
    field :state, 'The current desired state of the app. One of STOPPED or STARTED.', default: 'STOPPED', valid_values: %w(STOPPED STARTED)
    field :detected_start_command, 'The command detected by the buildpack during staging.', read_only: true
    field :command, "The command to start an app after it is staged, maximum length: 4096 (e.g. 'rails s -p $PORT' or 'java com.org.Server $PORT')."

    field :buildpack,
      'Buildpack to build the app. 3 options: a) Blank means autodetection; b) A Git Url pointing to a buildpack; c) Name of an installed buildpack.',
      default: '',
      example_values: ['', 'https://github.com/virtualstaticvoid/heroku-buildpack-r.git', 'an_example_installed_buildpack']

    field :health_check_type, 'Type of health check to perform.', default: 'port', valid_values: ['port', 'none']
    field :health_check_timeout, 'Timeout for health checking of an staged app when starting up'

    field :diego, 'Use diego to stage and to run when available', default: false, experimental: true, valid_values: [true, false]
    field :docker_image,
      'Name of the Docker image containing the app',
      default: nil,
      experimental: true,
      example_values: ['cloudfoundry/helloworld', 'registry.example.com:5000/user/repository/tag']

    field :environment_json, 'Key/value pairs of all the environment variables to run in your app. Does not include any system or service variables.'
    field :production, 'Deprecated.', deprecated: true, default: true, valid_values: [true, false]
    field :console, 'Open the console port for the app (at $CONSOLE_PORT).', deprecated: true, default: false, valid_values: [true, false]
    field :debug, 'Open the debug port for the app (at $DEBUG_PORT).', deprecated: true, default: false, valid_values: [true, false]
  end

  describe 'Standard endpoints' do
    include_context 'fields', required: false
    standard_model_list :app, VCAP::CloudController::AppsController
    standard_model_get :app, nested_associations: [:stack, :space]
    standard_model_delete_without_async :app

    before do
      allow(VCAP::CloudController::Config.config).to receive(:[]).with(anything).and_call_original
      allow(VCAP::CloudController::Config.config).to receive(:[]).with(:diego).and_return(
        staging: 'optional',
        running: 'optional',
      )
      allow(VCAP::CloudController::Config.config).to receive(:[]).with(:diego_docker).and_return true
    end

    def after_standard_model_delete(guid)
      event = VCAP::CloudController::Event.find(type: 'audit.app.delete-request', actee: guid)
      audited_event event
    end

    post '/v2/apps/' do
      include_context 'fields', required: true
      example 'Creating an App' do
        space_guid = VCAP::CloudController::Space.make.guid
        client.post '/v2/apps', MultiJson.dump(required_fields.merge(space_guid: space_guid), pretty: true), headers
        expect(status).to eq(201)

        standard_entity_response parsed_response, :app

        app_guid = parsed_response['metadata']['guid']
        audited_event VCAP::CloudController::Event.find(type: 'audit.app.create', actee: app_guid)
      end

      example 'Creating a Docker App (experimental)' do
        space_guid = VCAP::CloudController::Space.make.guid

        data = required_fields.merge(space_guid: space_guid, name: 'docker_app', docker_image: 'cloudfoundry/hello', diego: true)
        client.post '/v2/apps', MultiJson.dump(data, pretty: true), headers
        expect(status).to eq(201)

        standard_entity_response parsed_response, :app
        expect(parsed_response['entity']['docker_image']).to eq('cloudfoundry/hello:latest')
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
        instance_guid = associated_service_instance.guid
        binding_guid = associated_service_binding.guid
        uri = URI(service_broker.broker_url)
        broker_url = uri.host + uri.path
        broker_auth = "#{service_broker.auth_username}:#{service_broker.auth_password}"
        stub_request(
          :delete,
          %r{https://#{broker_auth}@#{broker_url}/v2/service_instances/#{instance_guid}/service_bindings/#{binding_guid}}).
          to_return(status: 200, body: '{}')
      end

      standard_model_list :service_binding, VCAP::CloudController::ServiceBindingsController, outer_model: :app
      nested_model_remove :service_binding, :app
    end

    describe 'Routes' do
      before do
        app_obj.add_route(associated_route)
      end
      let!(:route) { VCAP::CloudController::Route.make(space: app_obj.space) }
      let(:route_guid) { route.guid }
      let(:associated_route) { VCAP::CloudController::Route.make(space: app_obj.space) }
      let(:associated_route_guid) { associated_route.guid }

      standard_model_list :route, VCAP::CloudController::RoutesController, outer_model: :app
      nested_model_associate :route, :app
      nested_model_remove :route, :app
    end
  end

  get '/v2/apps/:guid/env' do
    include_context 'guid_parameter'
    let(:app_obj) { VCAP::CloudController::AppFactory.make(detected_buildpack: 'buildpack-name', environment_json: { env_var: 'env_val' }) }

    before do
      VCAP::CloudController::EnvironmentVariableGroup.make name: :staging, environment_json: { STAGING_ENV: 'staging_value' }
      VCAP::CloudController::EnvironmentVariableGroup.make name: :running, environment_json: { RUNNING_ENV: 'running_value' }
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
        Get status for each instance of an App using the app guid.
      EOD

      instances = {
        0 => {
          state: 'RUNNING',
          since: 1403140717.984577,
          debug_ip: nil,
          debug_port: nil,
          console_ip: nil,
          console_port: nil
        },
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
              mem: 29880320,
              cpu: 0.13511219703079957,
              time: '2014-06-19 22:37:58 +0000'
            },
            name: 'app_name',
            uris: [
              'app_name.example.com'
            ],
            host: '10.0.0.1',
            port: 61035,
            uptime: 65007,
            mem_quota: 536870912,
            disk_quota: 1073741824,
            fds_quota: 16384
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
