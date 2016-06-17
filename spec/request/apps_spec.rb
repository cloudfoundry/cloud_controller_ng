require 'spec_helper'

RSpec.describe 'Apps' do
  let(:user) { VCAP::CloudController::User.make }
  let(:user_header) { headers_for(user) }
  let(:space) { VCAP::CloudController::Space.make }

  before do
    space.organization.add_user(user)
    space.add_developer(user)
  end

  describe 'POST /v3/apps' do
    it 'creates an app' do
      buildpack      = VCAP::CloudController::Buildpack.make
      create_request = {
        name:                  'my_app',
        environment_variables: { open: 'source' },
        lifecycle:             {
          type: 'buildpack',
          data: {
            stack:     nil,
            buildpack: buildpack.name
          }
        },
        relationships:         {
          space: { guid: space.guid }
        }
      }

      post '/v3/apps', create_request, user_header

      created_app       = VCAP::CloudController::AppModel.last
      expected_response = {
        'name'                    => 'my_app',
        'guid'                    => created_app.guid,
        'desired_state'           => 'STOPPED',
        'total_desired_instances' => 0,
        'lifecycle'               => {
          'type' => 'buildpack',
          'data' => {
            'buildpack' => buildpack.name,
            'stack'     => VCAP::CloudController::Stack.default.name,
          }
        },
        'created_at'              => iso8601,
        'updated_at'              => nil,
        'environment_variables'   => { 'open' => 'source' },
        'links'                   => {
          'self'                   => { 'href' => "/v3/apps/#{created_app.guid}" },
          'processes'              => { 'href' => "/v3/apps/#{created_app.guid}/processes" },
          'packages'               => { 'href' => "/v3/apps/#{created_app.guid}/packages" },
          'space'                  => { 'href' => "/v2/spaces/#{space.guid}" },
          'droplet'                => { 'href' => "/v3/apps/#{created_app.guid}/droplets/current" },
          'droplets'               => { 'href' => "/v3/apps/#{created_app.guid}/droplets" },
          'tasks'                  => { 'href' => "/v3/apps/#{created_app.guid}/tasks" },
          'route_mappings'         => { 'href' => "/v3/apps/#{created_app.guid}/route_mappings" },
          'start'                  => { 'href' => "/v3/apps/#{created_app.guid}/start", 'method' => 'PUT' },
          'stop'                   => { 'href' => "/v3/apps/#{created_app.guid}/stop", 'method' => 'PUT' },
        }
      }

      parsed_response = MultiJson.load(last_response.body)
      expect(last_response.status).to eq(201)
      expect(parsed_response).to be_a_response_like(expected_response)

      event = VCAP::CloudController::Event.last
      expect(event.values).to include({
        type:              'audit.app.create',
        actee:             created_app.guid,
        actee_type:        'v3-app',
        actee_name:        'my_app',
        actor:             user.guid,
        actor_type:        'user',
        space_guid:        space.guid,
        organization_guid: space.organization.guid,
      })
    end

    describe 'Docker app' do
      before do
        VCAP::CloudController::FeatureFlag.make(name: 'diego_docker', enabled: true, error_message: nil)
      end

      it 'create a docker app' do
        create_request = {
          name:                  'my_app',
          environment_variables: { open: 'source' },
          lifecycle:             {
            type: 'docker',
            data: {}
          },
          relationships:         {
            space: { guid: space.guid }
          }
        }

        post '/v3/apps', create_request.to_json, user_header.merge({ 'CONTENT_TYPE' => 'application/json' })

        created_app       = VCAP::CloudController::AppModel.last
        expected_response = {
          'name'                    => 'my_app',
          'guid'                    => created_app.guid,
          'desired_state'           => 'STOPPED',
          'total_desired_instances' => 0,
          'lifecycle'               => {
            'type' => 'docker',
            'data' => {}
          },
          'created_at'              => iso8601,
          'updated_at'              => nil,
          'environment_variables'   => { 'open' => 'source' },
          'links'                   => {
            'self'                   => { 'href' => "/v3/apps/#{created_app.guid}" },
            'processes'              => { 'href' => "/v3/apps/#{created_app.guid}/processes" },
            'packages'               => { 'href' => "/v3/apps/#{created_app.guid}/packages" },
            'space'                  => { 'href' => "/v2/spaces/#{space.guid}" },
            'droplet'                => { 'href' => "/v3/apps/#{created_app.guid}/droplets/current" },
            'droplets'               => { 'href' => "/v3/apps/#{created_app.guid}/droplets" },
            'tasks'                  => { 'href' => "/v3/apps/#{created_app.guid}/tasks" },
            'route_mappings'         => { 'href' => "/v3/apps/#{created_app.guid}/route_mappings" },
            'start'                  => { 'href' => "/v3/apps/#{created_app.guid}/start", 'method' => 'PUT' },
            'stop'                   => { 'href' => "/v3/apps/#{created_app.guid}/stop", 'method' => 'PUT' },
          }
        }

        parsed_response = MultiJson.load(last_response.body)
        expect(last_response.status).to eq(201)
        expect(parsed_response).to be_a_response_like(expected_response)

        event = VCAP::CloudController::Event.last
        expect(event.values).to include({
          type:              'audit.app.create',
          actee:             created_app.guid,
          actee_type:        'v3-app',
          actee_name:        'my_app',
          actor:             user.guid,
          actor_type:        'user',
          space_guid:        space.guid,
          organization_guid: space.organization.guid,
        })
      end
    end
  end

  describe 'GET /v3/apps' do
    it 'returns a paginated list of apps the user has access to' do
      buildpack                           = VCAP::CloudController::Buildpack.make(name: 'bp-name')
      stack                               = VCAP::CloudController::Stack.make(name: 'stack-name')
      app_model1                          = VCAP::CloudController::AppModel.make(:buildpack,
        name:          'name1',
        space:         space,
        desired_state: 'STOPPED'
      )
      app_model1.lifecycle_data.buildpack = buildpack.name
      app_model1.lifecycle_data.stack     = stack.name
      app_model1.lifecycle_data.save

      app_model2 = VCAP::CloudController::AppModel.make(
        :docker,
        name:          'name2',
        space:         space,
        desired_state: 'STARTED'
      )
      VCAP::CloudController::AppModel.make(space: space)
      VCAP::CloudController::AppModel.make

      get '/v3/apps?per_page=2', nil, user_header

      expected_response = {
        'pagination' => {
          'total_results' => 3,
          'total_pages'   => 2,
          'first'         => { 'href' => '/v3/apps?page=1&per_page=2' },
          'last'          => { 'href' => '/v3/apps?page=2&per_page=2' },
          'next'          => { 'href' => '/v3/apps?page=2&per_page=2' },
          'previous'      => nil,
        },
        'resources' => [
          {
            'guid'                    => app_model1.guid,
            'name'                    => 'name1',
            'desired_state'           => 'STOPPED',
            'total_desired_instances' => 0,
            'lifecycle'               => {
              'type' => 'buildpack',
              'data' => {
                'buildpack' => 'bp-name',
                'stack'     => 'stack-name',
              }
            },
            'created_at'              => iso8601,
            'updated_at'              => iso8601,
            'environment_variables'   => {
              'redacted_message' => '[PRIVATE DATA HIDDEN IN LISTS]'
            },
            'links' => {
              'self'                   => { 'href' => "/v3/apps/#{app_model1.guid}" },
              'processes'              => { 'href' => "/v3/apps/#{app_model1.guid}/processes" },
              'packages'               => { 'href' => "/v3/apps/#{app_model1.guid}/packages" },
              'space'                  => { 'href' => "/v2/spaces/#{space.guid}" },
              'droplet'                => { 'href' => "/v3/apps/#{app_model1.guid}/droplets/current" },
              'droplets'               => { 'href' => "/v3/apps/#{app_model1.guid}/droplets" },
              'tasks'                  => { 'href' => "/v3/apps/#{app_model1.guid}/tasks" },
              'route_mappings'         => { 'href' => "/v3/apps/#{app_model1.guid}/route_mappings" },
              'start'                  => { 'href' => "/v3/apps/#{app_model1.guid}/start", 'method' => 'PUT' },
              'stop'                   => { 'href' => "/v3/apps/#{app_model1.guid}/stop", 'method' => 'PUT' },
            }
          },
          {
            'guid'                    => app_model2.guid,
            'name'                    => 'name2',
            'desired_state'           => 'STARTED',
            'total_desired_instances' => 0,
            'lifecycle'               => {
              'type' => 'docker',
              'data' => {}
            },
            'created_at'              => iso8601,
            'updated_at'              => nil,
            'environment_variables'   => {
              'redacted_message' => '[PRIVATE DATA HIDDEN IN LISTS]'
            },
            'links' => {
              'self'                   => { 'href' => "/v3/apps/#{app_model2.guid}" },
              'processes'              => { 'href' => "/v3/apps/#{app_model2.guid}/processes" },
              'packages'               => { 'href' => "/v3/apps/#{app_model2.guid}/packages" },
              'space'                  => { 'href' => "/v2/spaces/#{space.guid}" },
              'droplet'                => { 'href' => "/v3/apps/#{app_model2.guid}/droplets/current" },
              'droplets'               => { 'href' => "/v3/apps/#{app_model2.guid}/droplets" },
              'tasks'                  => { 'href' => "/v3/apps/#{app_model2.guid}/tasks" },
              'route_mappings'         => { 'href' => "/v3/apps/#{app_model2.guid}/route_mappings" },
              'start'                  => { 'href' => "/v3/apps/#{app_model2.guid}/start", 'method' => 'PUT' },
              'stop'                   => { 'href' => "/v3/apps/#{app_model2.guid}/stop", 'method' => 'PUT' },
            }
          }
        ]
      }

      parsed_response = MultiJson.load(last_response.body)

      expect(last_response.status).to eq(200)
      expect(parsed_response).to be_a_response_like(expected_response)
    end

    context 'faceted search' do
      let(:admin_header) { headers_for(user, scopes: %w(cloud_controller.admin)) }

      it 'filters by guids' do
        app_model1 = VCAP::CloudController::AppModel.make(name: 'name1')
        VCAP::CloudController::AppModel.make(name: 'name2')
        app_model3 = VCAP::CloudController::AppModel.make(name: 'name3')

        get "/v3/apps?guids=#{app_model1.guid}%2C#{app_model3.guid}", nil, admin_header

        expected_pagination = {
          'total_results' => 2,
          'total_pages'   => 1,
          'first'         => { 'href' => "/v3/apps?guids=#{app_model1.guid}%2C#{app_model3.guid}&page=1&per_page=50" },
          'last'          => { 'href' => "/v3/apps?guids=#{app_model1.guid}%2C#{app_model3.guid}&page=1&per_page=50" },
          'next'          => nil,
          'previous'      => nil
        }

        parsed_response = MultiJson.load(last_response.body)

        expect(last_response.status).to eq(200)
        expect(parsed_response['resources'].map { |r| r['name'] }).to eq(['name1', 'name3'])
        expect(parsed_response['pagination']).to eq(expected_pagination)
      end

      it 'filters by names' do
        VCAP::CloudController::AppModel.make(name: 'name1')
        VCAP::CloudController::AppModel.make(name: 'name2')
        VCAP::CloudController::AppModel.make(name: 'name3')

        get '/v3/apps?names=name1%2Cname2', nil, admin_header

        expected_pagination = {
          'total_results' => 2,
          'total_pages'   => 1,
          'first'         => { 'href' => '/v3/apps?names=name1%2Cname2&page=1&per_page=50' },
          'last'          => { 'href' => '/v3/apps?names=name1%2Cname2&page=1&per_page=50' },
          'next'          => nil,
          'previous'      => nil
        }

        parsed_response = MultiJson.load(last_response.body)

        expect(last_response.status).to eq(200)
        expect(parsed_response['resources'].map { |r| r['name'] }).to eq(['name1', 'name2'])
        expect(parsed_response['pagination']).to eq(expected_pagination)
      end

      it 'filters by organizations' do
        app_model1 = VCAP::CloudController::AppModel.make(name: 'name1')
        VCAP::CloudController::AppModel.make(name: 'name2')
        app_model3 = VCAP::CloudController::AppModel.make(name: 'name3')

        get "/v3/apps?organization_guids=#{app_model1.organization.guid}%2C#{app_model3.organization.guid}", nil, admin_header

        expected_pagination = {
          'total_results' => 2,
          'total_pages'   => 1,
          'first'         => { 'href' => "/v3/apps?organization_guids=#{app_model1.organization.guid}%2C#{app_model3.organization.guid}&page=1&per_page=50" },
          'last'          => { 'href' => "/v3/apps?organization_guids=#{app_model1.organization.guid}%2C#{app_model3.organization.guid}&page=1&per_page=50" },
          'next'          => nil,
          'previous'      => nil
        }

        parsed_response = MultiJson.load(last_response.body)

        expect(last_response.status).to eq(200)
        expect(parsed_response['resources'].map { |r| r['name'] }).to eq(['name1', 'name3'])
        expect(parsed_response['pagination']).to eq(expected_pagination)
      end

      it 'filters by spaces' do
        app_model1 = VCAP::CloudController::AppModel.make(name: 'name1')
        VCAP::CloudController::AppModel.make(name: 'name2')
        app_model3 = VCAP::CloudController::AppModel.make(name: 'name3')

        get "/v3/apps?space_guids=#{app_model1.space.guid}%2C#{app_model3.space.guid}", nil, admin_header

        expected_pagination = {
          'total_results' => 2,
          'total_pages'   => 1,
          'first'         => { 'href' => "/v3/apps?page=1&per_page=50&space_guids=#{app_model1.space.guid}%2C#{app_model3.space.guid}" },
          'last'          => { 'href' => "/v3/apps?page=1&per_page=50&space_guids=#{app_model1.space.guid}%2C#{app_model3.space.guid}" },
          'next'          => nil,
          'previous'      => nil
        }

        parsed_response = MultiJson.load(last_response.body)

        expect(last_response.status).to eq(200)
        expect(parsed_response['resources'].map { |r| r['name'] }).to eq(['name1', 'name3'])
        expect(parsed_response['pagination']).to eq(expected_pagination)
      end
    end
  end

  describe 'GET /v3/apps/:guid' do
    it 'gets a specific app' do
      buildpack                          = VCAP::CloudController::Buildpack.make(name: 'bp-name')
      stack                              = VCAP::CloudController::Stack.make(name: 'stack-name')
      app_model                          = VCAP::CloudController::AppModel.make(
        :buildpack,
        name:                  'my_app',
        space:                 space,
        desired_state:         'STARTED',
        environment_variables: { 'unicorn' => 'horn' },
        droplet_guid:          'a-droplet-guid'
      )
      app_model.lifecycle_data.buildpack = buildpack.name
      app_model.lifecycle_data.stack     = stack.name
      app_model.lifecycle_data.save
      app_model.add_process(VCAP::CloudController::App.make(space: space, instances: 1))
      app_model.add_process(VCAP::CloudController::App.make(space: space, instances: 2))

      get "/v3/apps/#{app_model.guid}", nil, user_header

      expected_response = {
        'name'                    => 'my_app',
        'guid'                    => app_model.guid,
        'desired_state'           => 'STARTED',
        'total_desired_instances' => 3,
        'created_at'              => iso8601,
        'updated_at'              => iso8601,
        'environment_variables'   => { 'unicorn' => 'horn' },
        'lifecycle'               => {
          'type' => 'buildpack',
          'data' => {
            'buildpack' => 'bp-name',
            'stack'     => 'stack-name',
          }
        },
        'links' => {
          'self'                   => { 'href' => "/v3/apps/#{app_model.guid}" },
          'processes'              => { 'href' => "/v3/apps/#{app_model.guid}/processes" },
          'packages'               => { 'href' => "/v3/apps/#{app_model.guid}/packages" },
          'space'                  => { 'href' => "/v2/spaces/#{space.guid}" },
          'droplet'                => { 'href' => "/v3/apps/#{app_model.guid}/droplets/current" },
          'droplets'               => { 'href' => "/v3/apps/#{app_model.guid}/droplets" },
          'tasks'                  => { 'href' => "/v3/apps/#{app_model.guid}/tasks" },
          'route_mappings'         => { 'href' => "/v3/apps/#{app_model.guid}/route_mappings" },
          'start'                  => { 'href' => "/v3/apps/#{app_model.guid}/start", 'method' => 'PUT' },
          'stop'                   => { 'href' => "/v3/apps/#{app_model.guid}/stop", 'method' => 'PUT' },
        }
      }

      parsed_response = MultiJson.load(last_response.body)
      expect(last_response.status).to eq(200)
      expect(parsed_response).to be_a_response_like(expected_response)
    end

    describe 'redacting' do
      it 'redacts fields for auditors' do
        app_model = VCAP::CloudController::AppModel.make(
          :buildpack,
          name:                  'my_app',
          space:                 space,
          environment_variables: { 'unicorn' => 'horn' },
        )

        auditor = VCAP::CloudController::User.make
        space.organization.add_user(auditor)
        space.add_auditor(auditor)

        get "/v3/apps/#{app_model.guid}", nil, headers_for(auditor)

        parsed_response = MultiJson.load(last_response.body)
        expect(last_response.status).to eq(200)
        expect(parsed_response['environment_variables']).to eq({ 'redacted_message' => '[PRIVATE DATA HIDDEN]' })
      end
    end
  end

  describe 'GET /v3/apps/:guid/env' do
    it 'returns the environment of the app, including environment variables provided by the system' do
      app_model = VCAP::CloudController::AppModel.make(
        name:                  'my_app',
        space:                 space,
        environment_variables: { 'unicorn' => 'horn' },
      )

      group                  = VCAP::CloudController::EnvironmentVariableGroup.staging
      group.environment_json = { STAGING_ENV: 'staging_value' }
      group.save

      group                  = VCAP::CloudController::EnvironmentVariableGroup.running
      group.environment_json = { RUNNING_ENV: 'running_value' }
      group.save

      service_instance = VCAP::CloudController::ManagedServiceInstance.make(
        space: space,
        name:  'si-name',
        tags:  ['50% off']
      )
      VCAP::CloudController::ServiceBindingModel.make(
        service_instance: service_instance,
        app:              app_model,
        syslog_drain_url: 'https://syslog.example.com/drain',
        credentials:      { password: 'top-secret' }
      )

      get "/v3/apps/#{app_model.guid}/env", nil, user_header

      expected_response = {
        'staging_env_json' => {
          'STAGING_ENV' => 'staging_value'
        },
        'running_env_json' => {
          'RUNNING_ENV' => 'running_value'
        },
        'environment_variables' => {
          'unicorn' => 'horn'
        },
        'system_env_json' => {
          'VCAP_SERVICES' => {
            service_instance.service.label => [
              {
                'name'             => 'si-name',
                'label'            => service_instance.service.label,
                'tags'             => ['50% off'],
                'plan'             => service_instance.service_plan.name,
                'credentials'      => { 'password' => 'top-secret' },
                'syslog_drain_url' => 'https://syslog.example.com/drain',
                'provider'         => nil,
                'volume_mounts'    => []
              }
            ]
          }
        },
        'application_env_json' => {
          'VCAP_APPLICATION' => {
            'limits' => {
              'fds' => 16384
            },
            'application_name' => 'my_app',
            'application_id'   => app_model.guid,
            'application_uris' => [],
            'name'             => 'my_app',
            'space_name'       => space.name,
            'space_id'         => space.guid,
            'uris'             => [],
            'users'            => nil
          }
        }
      }

      parsed_response = MultiJson.load(last_response.body)

      expect(last_response.status).to eq(200)
      expect(parsed_response).to be_a_response_like(expected_response)
    end
  end

  describe 'DELETE /v3/apps/guid' do
    let!(:app_model) { VCAP::CloudController::AppModel.make(name: 'app_name', space: space) }
    let!(:package) { VCAP::CloudController::PackageModel.make(app: app_model) }
    let!(:droplet) { VCAP::CloudController::DropletModel.make(package: package, app: app_model) }
    let!(:process) { VCAP::CloudController::AppFactory.make(app: app_model, space: space) }

    it 'deletes an App' do
      delete "/v3/apps/#{app_model.guid}", nil, user_header

      expect(last_response.status).to eq(204)

      expect(app_model.exists?).to be_falsey
      expect(package.exists?).to be_falsey
      expect(droplet.exists?).to be_falsey
      expect(process.exists?).to be_falsey

      event = VCAP::CloudController::Event.last(2).first
      expect(event.values).to include({
        type:              'audit.app.delete-request',
        actee:             app_model.guid,
        actee_type:        'v3-app',
        actee_name:        'app_name',
        actor:             user.guid,
        actor_type:        'user',
        space_guid:        space.guid,
        organization_guid: space.organization.guid
      })
    end
  end

  describe 'PATCH /v3/apps/:guid' do
    it 'updates an app' do
      app_model = VCAP::CloudController::AppModel.make(
        :buildpack,
        name:                  'original_name',
        space:                 space,
        environment_variables: { 'ORIGINAL' => 'ENVAR' },
        desired_state:         'STOPPED'
      )
      stack = VCAP::CloudController::Stack.make(name: 'redhat')

      update_request = {
        name:                  'new-name',
        environment_variables: { 'NEWENV' => 'VARIABLE' },
        lifecycle:             {
          type: 'buildpack',
          data: {
            buildpack: 'http://gitwheel.org/my-app',
            stack:     stack.name
          }
        }
      }

      patch "/v3/apps/#{app_model.guid}", update_request, headers_for(user)

      app_model.reload
      expected_response = {
        'name'                    => 'new-name',
        'guid'                    => app_model.guid,
        'desired_state'           => 'STOPPED',
        'total_desired_instances' => 0,
        'lifecycle'               => {
          'type' => 'buildpack',
          'data' => {
            'buildpack' => 'http://gitwheel.org/my-app',
            'stack'     => stack.name,
          }
        },
        'created_at'              => iso8601,
        'updated_at'              => iso8601,
        'environment_variables'   => { 'NEWENV' => 'VARIABLE' },
        'links'                   => {
          'self'                   => { 'href' => "/v3/apps/#{app_model.guid}" },
          'processes'              => { 'href' => "/v3/apps/#{app_model.guid}/processes" },
          'packages'               => { 'href' => "/v3/apps/#{app_model.guid}/packages" },
          'space'                  => { 'href' => "/v2/spaces/#{space.guid}" },
          'droplet'                => { 'href' => "/v3/apps/#{app_model.guid}/droplets/current" },
          'droplets'               => { 'href' => "/v3/apps/#{app_model.guid}/droplets" },
          'tasks'                  => { 'href' => "/v3/apps/#{app_model.guid}/tasks" },
          'route_mappings'         => { 'href' => "/v3/apps/#{app_model.guid}/route_mappings" },
          'start'                  => { 'href' => "/v3/apps/#{app_model.guid}/start", 'method' => 'PUT' },
          'stop'                   => { 'href' => "/v3/apps/#{app_model.guid}/stop", 'method' => 'PUT' },
        }
      }

      parsed_response = MultiJson.load(last_response.body)
      expect(last_response.status).to eq(200)
      expect(parsed_response).to be_a_response_like(expected_response)

      event = VCAP::CloudController::Event.last
      expect(event.values).to include({
        type:              'audit.app.update',
        actee:             app_model.guid,
        actee_type:        'v3-app',
        actee_name:        'new-name',
        actor:             user.guid,
        actor_type:        'user',
        space_guid:        space.guid,
        organization_guid: space.organization.guid
      })

      metadata_request = { 'name' => 'new-name', 'environment_variables' => 'PRIVATE DATA HIDDEN',
                           'lifecycle' => { 'type' => 'buildpack', 'data' => { 'buildpack' => 'http://gitwheel.org/my-app', 'stack' => stack.name } } }
      expect(event.metadata['request']).to eq(metadata_request)
    end
  end

  describe 'PUT /v3/apps/:guid/start' do
    it 'starts the app' do
      stack     = VCAP::CloudController::Stack.make(name: 'stack-name')
      app_model = VCAP::CloudController::AppModel.make(
        :buildpack,
        name:          'app-name',
        space:         space,
        desired_state: 'STOPPED',
      )

      app_model.lifecycle_data.buildpack = 'http://example.com/git'
      app_model.lifecycle_data.stack     = stack.name
      app_model.lifecycle_data.save

      droplet           = VCAP::CloudController::DropletModel.make(:buildpack, app: app_model, state: VCAP::CloudController::DropletModel::STAGED_STATE)
      app_model.droplet = droplet
      app_model.save

      put "/v3/apps/#{app_model.guid}/start", nil, user_header

      expected_response = {
        'name'                    => 'app-name',
        'guid'                    => app_model.guid,
        'desired_state'           => 'STARTED',
        'total_desired_instances' => 0,
        'created_at'              => iso8601,
        'updated_at'              => iso8601,
        'environment_variables'   => {},
        'lifecycle'               => {
          'type' => 'buildpack',
          'data' => {
            'buildpack' => 'http://example.com/git',
            'stack'     => 'stack-name',
          }
        },
        'links' => {
          'self'                   => { 'href' => "/v3/apps/#{app_model.guid}" },
          'processes'              => { 'href' => "/v3/apps/#{app_model.guid}/processes" },
          'packages'               => { 'href' => "/v3/apps/#{app_model.guid}/packages" },
          'space'                  => { 'href' => "/v2/spaces/#{space.guid}" },
          'droplet'                => { 'href' => "/v3/apps/#{app_model.guid}/droplets/current" },
          'droplets'               => { 'href' => "/v3/apps/#{app_model.guid}/droplets" },
          'tasks'                  => { 'href' => "/v3/apps/#{app_model.guid}/tasks" },
          'route_mappings'         => { 'href' => "/v3/apps/#{app_model.guid}/route_mappings" },
          'start'                  => { 'href' => "/v3/apps/#{app_model.guid}/start", 'method' => 'PUT' },
          'stop'                   => { 'href' => "/v3/apps/#{app_model.guid}/stop", 'method' => 'PUT' },
        }
      }

      parsed_response = MultiJson.load(last_response.body)

      expect(last_response.status).to eq(200)
      expect(parsed_response).to be_a_response_like(expected_response)

      event = VCAP::CloudController::Event.last
      expect(event.values).to include({
        type:              'audit.app.start',
        actee:             app_model.guid,
        actee_type:        'v3-app',
        actee_name:        'app-name',
        actor:             user.guid,
        actor_type:        'user',
        space_guid:        space.guid,
        organization_guid: space.organization.guid,
      })
    end
  end

  describe 'PUT /v3/apps/:guid/stop' do
    it 'stops the app' do
      stack     = VCAP::CloudController::Stack.make(name: 'stack-name')
      app_model = VCAP::CloudController::AppModel.make(
        :buildpack,
        name:          'app-name',
        space:         space,
        desired_state: 'STARTED',
      )

      app_model.lifecycle_data.buildpack = 'http://example.com/git'
      app_model.lifecycle_data.stack     = stack.name
      app_model.lifecycle_data.save

      droplet           = VCAP::CloudController::DropletModel.make(:buildpack, app: app_model, state: VCAP::CloudController::DropletModel::STAGED_STATE)
      app_model.droplet = droplet
      app_model.save

      put "/v3/apps/#{app_model.guid}/stop", nil, user_header

      expected_response = {
        'name'                    => 'app-name',
        'guid'                    => app_model.guid,
        'desired_state'           => 'STOPPED',
        'total_desired_instances' => 0,
        'created_at'              => iso8601,
        'updated_at'              => iso8601,
        'environment_variables'   => {},
        'lifecycle'               => {
          'type' => 'buildpack',
          'data' => {
            'buildpack' => 'http://example.com/git',
            'stack'     => 'stack-name',
          }
        },
        'links' => {
          'self'                   => { 'href' => "/v3/apps/#{app_model.guid}" },
          'processes'              => { 'href' => "/v3/apps/#{app_model.guid}/processes" },
          'packages'               => { 'href' => "/v3/apps/#{app_model.guid}/packages" },
          'space'                  => { 'href' => "/v2/spaces/#{space.guid}" },
          'droplet'                => { 'href' => "/v3/apps/#{app_model.guid}/droplets/current" },
          'droplets'               => { 'href' => "/v3/apps/#{app_model.guid}/droplets" },
          'tasks'                  => { 'href' => "/v3/apps/#{app_model.guid}/tasks" },
          'route_mappings'         => { 'href' => "/v3/apps/#{app_model.guid}/route_mappings" },
          'start'                  => { 'href' => "/v3/apps/#{app_model.guid}/start", 'method' => 'PUT' },
          'stop'                   => { 'href' => "/v3/apps/#{app_model.guid}/stop", 'method' => 'PUT' },
        }
      }

      parsed_response = MultiJson.load(last_response.body)

      expect(last_response.status).to eq(200)
      expect(parsed_response).to be_a_response_like(expected_response)

      event = VCAP::CloudController::Event.last
      expect(event.values).to include({
        type:              'audit.app.stop',
        actee:             app_model.guid,
        actee_type:        'v3-app',
        actee_name:        'app-name',
        actor:             user.guid,
        actor_type:        'user',
        space_guid:        space.guid,
        organization_guid: space.organization.guid,
      })
    end
  end

  describe 'GET /v3/apps/:guid/droplets/current' do
    let(:app_model) { VCAP::CloudController::AppModel.make(space_guid: space.guid) }
    let(:guid) { droplet_model.guid }
    let(:package_model) { VCAP::CloudController::PackageModel.make(app_guid: app_model.guid) }
    let!(:droplet_model) do
      VCAP::CloudController::DropletModel.make(
        state:                       VCAP::CloudController::DropletModel::STAGED_STATE,
        app_guid:                    app_model.guid,
        package_guid:                package_model.guid,
        buildpack_receipt_buildpack: 'http://buildpack.git.url.com',
        buildpack_receipt_stack_name: 'stack-name',
        error:                       'example error',
        environment_variables:       { 'cloud' => 'foundry' },
        execution_metadata: 'some-data',
        droplet_hash: 'shalalala',
        process_types: { 'web' => 'start-command' },
        staging_memory_in_mb: 100,
        staging_disk_in_mb: 200,
      )
    end
    let(:app_guid) { droplet_model.app_guid }

    before do
      droplet_model.buildpack_lifecycle_data.update(buildpack: 'http://buildpack.git.url.com', stack: 'stack-name')
      app_model.droplet_guid = droplet_model.guid
      app_model.save
    end

    it 'gets the current droplet' do
      get "/v3/apps/#{app_model.guid}/droplets/current", nil, user_header

      parsed_response = MultiJson.load(last_response.body)

      expect(last_response.status).to eq(200)
      expect(parsed_response).to be_a_response_like({
        'guid'                  => droplet_model.guid,
        'state'                 => VCAP::CloudController::DropletModel::STAGED_STATE,
        'error'                 => 'example error',
        'lifecycle'             => {
          'type' => 'buildpack',
          'data' => {
            'buildpack' => 'http://buildpack.git.url.com',
            'stack'     => 'stack-name'
          }
        },
        'staging_memory_in_mb' => 100,
        'staging_disk_in_mb' => 200,
        'result' => {
          'hash'                   => { 'type' => 'sha1', 'value' => 'shalalala' },
          'buildpack'              => 'http://buildpack.git.url.com',
          'stack'                  => 'stack-name',
          'execution_metadata'     => 'some-data',
          'process_types'          => { 'web' => 'start-command' }
        },
        'environment_variables' => { 'cloud' => 'foundry' },
        'created_at'            => iso8601,
        'updated_at'            => iso8601,
        'links'                 => {
          'self'                   => { 'href' => "/v3/droplets/#{guid}" },
          'package'                => { 'href' => "/v3/packages/#{package_model.guid}" },
          'app'                    => { 'href' => "/v3/apps/#{app_guid}" },
          'assign_current_droplet' => { 'href' => "/v3/apps/#{app_guid}/droplets/current", 'method' => 'PUT' },
        }
      })
    end
  end

  describe 'PUT /v3/apps/:guid/droplets/current' do
    let(:stack) { VCAP::CloudController::Stack.make(name: 'stack-name') }
    let(:app_model) do
      VCAP::CloudController::AppModel.make(
        :buildpack,
        name:          'my_app',
        space:         space,
        desired_state: 'STOPPED',
      )
    end

    before do
      app_model.lifecycle_data.buildpack = 'http://example.com/git'
      app_model.lifecycle_data.stack     = stack.name
      app_model.lifecycle_data.save
    end

    it 'assigns the current droplet of the app' do
      droplet = VCAP::CloudController::DropletModel.make(:docker,
        app:           app_model,
        process_types: { web: 'rackup' },
        state:         VCAP::CloudController::DropletModel::STAGED_STATE,
        package: VCAP::CloudController::PackageModel.make
      )

      request_body = { droplet_guid: droplet.guid }

      put "/v3/apps/#{app_model.guid}/droplets/current", request_body, user_header

      expected_response = {
        'guid'                  => droplet.guid,
        'state'                 => VCAP::CloudController::DropletModel::STAGED_STATE,
        'error'                 => nil,
        'lifecycle'             => {
          'type' => 'docker',
          'data' => {}
        },
        'staging_memory_in_mb' => 123,
        'staging_disk_in_mb'   => nil,
        'result' => {
          'image'                  => nil,
          'execution_metadata'     => nil,
          'process_types'          => { 'web' => 'rackup' }
        },
        'environment_variables' => {},
        'created_at'            => iso8601,
        'updated_at'            => iso8601,
        'links'                 => {
          'self'                   => { 'href' => "/v3/droplets/#{droplet.guid}" },
          'package'                => { 'href' => "/v3/packages/#{droplet.package.guid}" },
          'app'                    => { 'href' => "/v3/apps/#{app_model.guid}" },
          'assign_current_droplet' => { 'href' => "/v3/apps/#{app_model.guid}/droplets/current", 'method' => 'PUT' },
        }
      }

      parsed_response = MultiJson.load(last_response.body)

      expect(last_response.status).to eq(200)
      expect(parsed_response).to be_a_response_like(expected_response)

      events = VCAP::CloudController::Event.where(actor: user.guid).all

      droplet_event = events.find { |e| e.type == 'audit.app.droplet_mapped' }
      expect(droplet_event.values).to include({
        type:              'audit.app.droplet_mapped',
        actee:             app_model.guid,
        actee_type:        'v3-app',
        actee_name:        'my_app',
        actor:             user.guid,
        actor_type:        'user',
        space_guid:        space.guid,
        organization_guid: space.organization.guid
      })
      expect(droplet_event.metadata).to eq({ 'request' => { 'droplet_guid' => droplet.guid } })

      expect(app_model.reload.processes.count).to eq(1)
    end

    it 'creates audit.app.process.create events' do
      droplet = VCAP::CloudController::DropletModel.make(
        app:           app_model,
        process_types: { web: 'rackup', other: 'cron' },
        state:         VCAP::CloudController::DropletModel::STAGED_STATE
      )

      request_body = { droplet_guid: droplet.guid }

      put "/v3/apps/#{app_model.guid}/droplets/current", request_body, user_header

      expect(last_response.status).to eq(200)

      events = VCAP::CloudController::Event.where(actor: user.guid).all

      expect(app_model.reload.processes.count).to eq(2)
      web_process   = app_model.processes.find { |i| i.type == 'web' }
      other_process = app_model.processes.find { |i| i.type == 'other' }
      expect(web_process).to be_present
      expect(other_process).to be_present

      web_process_event = events.find { |e| e.metadata['process_guid'] == web_process.guid }
      expect(web_process_event.values).to include({
        type:              'audit.app.process.create',
        actee:             app_model.guid,
        actee_type:        'v3-app',
        actee_name:        'my_app',
        actor:             user.guid,
        actor_type:        'user',
        space_guid:        space.guid,
        organization_guid: space.organization.guid
      })
      expect(web_process_event.metadata).to eq({ 'process_guid' => web_process.guid, 'process_type' => 'web' })

      other_process_event = events.find { |e| e.metadata['process_guid'] == other_process.guid }
      expect(other_process_event.values).to include({
        type:              'audit.app.process.create',
        actee:             app_model.guid,
        actee_type:        'v3-app',
        actee_name:        'my_app',
        actor:             user.guid,
        actor_type:        'user',
        space_guid:        space.guid,
        organization_guid: space.organization.guid
      })
      expect(other_process_event.metadata).to eq({ 'process_guid' => other_process.guid, 'process_type' => 'other' })
    end

    it 'creates audit.app.process.update events' do
      process_to_update = VCAP::CloudController::ProcessModel.make(app: app_model, type: 'web', command: 'original', space: app_model.space, metadata: {})

      droplet = VCAP::CloudController::DropletModel.make(
        app:           app_model,
        process_types: { web: 'rackup' },
        state:         VCAP::CloudController::DropletModel::STAGED_STATE
      )

      request_body = { droplet_guid: droplet.guid }

      put "/v3/apps/#{app_model.guid}/droplets/current", request_body, user_header

      expect(last_response.status).to eq(200)

      events = VCAP::CloudController::Event.where(actor: user.guid).all

      expect(app_model.reload.processes.count).to eq(1)

      update_event = events.find { |e| e.metadata['process_guid'] == process_to_update.guid }
      expect(update_event.values).to include({
        type:              'audit.app.process.update',
        actee:             app_model.guid,
        actee_type:        'v3-app',
        actee_name:        'my_app',
        actor:             user.guid,
        actor_type:        'user',
        space_guid:        space.guid,
        organization_guid: space.organization.guid
      })
      expect(update_event.metadata).to eq({
        'process_guid' => process_to_update.guid,
        'process_type' => 'web',
        'request'      => {
          'command' => 'PRIVATE DATA HIDDEN'
        }
      })
    end

    it 'creates audit.app.process.delete events' do
      process_to_delete = VCAP::CloudController::ProcessModel.make(app: app_model, type: 'bob', space: app_model.space)

      droplet = VCAP::CloudController::DropletModel.make(
        app:           app_model,
        process_types: { web: 'rackup' },
        state:         VCAP::CloudController::DropletModel::STAGED_STATE
      )

      request_body = { droplet_guid: droplet.guid }

      put "/v3/apps/#{app_model.guid}/droplets/current", request_body, user_header

      expect(last_response.status).to eq(200)

      events = VCAP::CloudController::Event.where(actor: user.guid).all

      expect(app_model.reload.processes.count).to eq(1)

      delete_event = events.find { |e| e.metadata['process_guid'] == process_to_delete.guid }
      expect(delete_event.values).to include({
        type:              'audit.app.process.delete',
        actee:             app_model.guid,
        actee_type:        'v3-app',
        actee_name:        'my_app',
        actor:             user.guid,
        actor_type:        'user',
        space_guid:        space.guid,
        organization_guid: space.organization.guid
      })
      expect(delete_event.metadata).to eq({ 'process_guid' => process_to_delete.guid, 'process_type' => 'bob' })
    end
  end
end
