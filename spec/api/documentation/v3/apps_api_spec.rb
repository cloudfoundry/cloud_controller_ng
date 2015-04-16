require 'spec_helper'
require 'awesome_print'
require 'rspec_api_documentation/dsl'

resource 'Apps (Experimental)', type: :api do
  let(:iso8601) { /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$/.freeze }
  let(:user) { VCAP::CloudController::User.make }
  let(:user_header) { headers_for(user)['HTTP_AUTHORIZATION'] }
  header 'AUTHORIZATION', :user_header

  def do_request_with_error_handling
    do_request
    if response_status > 299
      error = MultiJson.load(response_body)
      ap error
      raise error['description']
    end
  end

  get '/v3/apps' do
    parameter :names, 'Names of apps to filter by', valid_values: 'array of strings', example_values: 'names[]=name1&names[]=name2'
    parameter :space_guids, 'Spaces to filter by', valid_values: 'array of strings', example_values: 'space_guids[]=space_guid1&space_guids[]=space_guid2'
    parameter :organization_guids, 'Organizations to filter by', valid_values: 'array of strings', example_values: 'organization_guids[]=org_guid1&organization_guids[]=org_guid2'
    parameter :guids, 'App guids to filter by', valid_values: 'array of strings', example_values: 'guid[]=guid1&guid[]=guid2'
    parameter :page, 'Page to display', valid_values: '>= 1'
    parameter :per_page, 'Number of results per page', valid_values: '1 - 5000'
    parameter :order_by, 'Value to sort by', valid_values: 'created_at, updated_at'
    parameter :order_direction, 'Direction to sort by', valid_values: 'asc, desc'

    let(:name1) { 'my_app1' }
    let(:name2) { 'my_app2' }
    let(:name3) { 'my_app3' }
    let(:environment_variables) { { 'magic' => 'beautiful' } }
    let!(:app_model1) { VCAP::CloudController::AppModel.make(name: name1, space_guid: space.guid, created_at: Time.at(1)) }
    let!(:app_model2) { VCAP::CloudController::AppModel.make(name: name2, space_guid: space.guid, created_at: Time.at(2)) }
    let!(:app_model3) { VCAP::CloudController::AppModel.make(name: name3, space_guid: space.guid, environment_variables: environment_variables, created_at: Time.at(3)) }
    let!(:app_model4) { VCAP::CloudController::AppModel.make(space_guid: VCAP::CloudController::Space.make.guid) }
    let(:space) { VCAP::CloudController::Space.make }
    let(:page) { 1 }
    let(:per_page) { 2 }
    let(:order_by) { 'created_at' }
    let(:order_direction) { 'desc' }

    before do
      space.organization.add_user user
      space.add_developer user
    end

    example 'List all Apps' do
      do_request_with_error_handling

      expected_response = {
        'pagination' => {
          'total_results' => 3,
          'first'         => { 'href' => "/v3/apps?order_by=#{order_by}&order_direction=#{order_direction}&page=1&per_page=2" },
          'last'          => { 'href' => "/v3/apps?order_by=#{order_by}&order_direction=#{order_direction}&page=2&per_page=2" },
          'next'          => { 'href' => "/v3/apps?order_by=#{order_by}&order_direction=#{order_direction}&page=2&per_page=2" },
          'previous'      => nil,
        },
        'resources'  => [
          {
            'name'   => name3,
            'guid'   => app_model3.guid,
            'desired_state' => app_model3.desired_state,
            'total_desired_instances' => 0,
            'created_at' => iso8601,
            'updated_at' => nil,
            'environment_variables' => environment_variables,
            '_links' => {
              'self'      => { 'href' => "/v3/apps/#{app_model3.guid}" },
              'processes' => { 'href' => "/v3/apps/#{app_model3.guid}/processes" },
              'packages'  => { 'href' => "/v3/apps/#{app_model3.guid}/packages" },
              'space'     => { 'href' => "/v2/spaces/#{space.guid}" },
              'start'     => { 'href' => "/v3/apps/#{app_model3.guid}/start", 'method' => 'PUT' },
              'stop'      => { 'href' => "/v3/apps/#{app_model3.guid}/stop", 'method' => 'PUT' },
              'assign_current_droplet' => { 'href' => "/v3/apps/#{app_model3.guid}/current_droplet", 'method' => 'PUT' }
            }
          },
          {
            'name'   => name2,
            'guid'   => app_model2.guid,
            'desired_state' => app_model3.desired_state,
            'total_desired_instances' => 0,
            'created_at' => iso8601,
            'updated_at' => nil,
            'environment_variables' => {},
            '_links' => {
              'self'      => { 'href' => "/v3/apps/#{app_model2.guid}" },
              'processes' => { 'href' => "/v3/apps/#{app_model2.guid}/processes" },
              'packages'  => { 'href' => "/v3/apps/#{app_model2.guid}/packages" },
              'space'     => { 'href' => "/v2/spaces/#{space.guid}" },
              'start'     => { 'href' => "/v3/apps/#{app_model2.guid}/start", 'method' => 'PUT' },
              'stop'      => { 'href' => "/v3/apps/#{app_model2.guid}/stop", 'method' => 'PUT' },
              'assign_current_droplet' => { 'href' => "/v3/apps/#{app_model2.guid}/current_droplet", 'method' => 'PUT' }
            }
          }
        ]
      }

      parsed_response = MultiJson.load(response_body)

      expect(response_status).to eq(200)
      expect(parsed_response).to be_a_response_like(expected_response)
    end

    context 'faceted search' do
      let(:app_model5) { VCAP::CloudController::AppModel.make(name: name1, space_guid: VCAP::CloudController::Space.make.guid) }
      let!(:app_model6) { VCAP::CloudController::AppModel.make(name: name1, space_guid: VCAP::CloudController::Space.make.guid) }
      let(:space_guids) { [app_model5.space_guid, space.guid, app_model6.space_guid] }
      let(:per_page) { 2 }
      let(:names) { [name1] }

      def space_guid_facets(space_guids)
        space_guids.map { |sg| "space_guids[]=#{sg}" }.join('&')
      end

      example 'Filters Apps by guids, names, spaces, and organizations' do
        user.admin = true
        user.save
        expected_pagination = {
          'total_results' => 3,
          'first'         => { 'href' => "/v3/apps?names[]=#{name1}&#{space_guid_facets(space_guids)}&order_by=#{order_by}&order_direction=#{order_direction}&page=1&per_page=2" },
          'last'          => { 'href' => "/v3/apps?names[]=#{name1}&#{space_guid_facets(space_guids)}&order_by=#{order_by}&order_direction=#{order_direction}&page=2&per_page=2" },
          'next'          => { 'href' => "/v3/apps?names[]=#{name1}&#{space_guid_facets(space_guids)}&order_by=#{order_by}&order_direction=#{order_direction}&page=2&per_page=2" },
          'previous'      => nil,
        }

        do_request_with_error_handling

        parsed_response = MultiJson.load(response_body)
        expect(response_status).to eq(200)
        expect(parsed_response['resources'].map { |r| r['name'] }).to eq(['my_app1', 'my_app1'])
        expect(parsed_response['pagination']).to eq(expected_pagination)
      end
    end
  end

  get '/v3/apps/:guid' do
    let(:desired_droplet_guid) { 'a-droplet-guid' }
    let(:environment_variables) { { 'darkness' => 'ugly' } }
    let(:app_model) { VCAP::CloudController::AppModel.make(name: name, desired_droplet_guid: desired_droplet_guid, environment_variables: environment_variables) }
    let(:process1) { VCAP::CloudController::App.make(space: space, instances: 1) }
    let(:process2) { VCAP::CloudController::App.make(space: space, instances: 2) }
    let(:guid) { app_model.guid }
    let(:space_guid) { app_model.space_guid }
    let(:space) { VCAP::CloudController::Space.find(guid: space_guid) }
    let(:name) { 'my_app' }

    before do
      space.organization.add_user user
      space.add_developer user

      app_model.add_process(process1)
      app_model.add_process(process2)
    end

    example 'Get an App' do
      do_request_with_error_handling

      expected_response = {
        'name'   => name,
        'guid'   => guid,
        'desired_state' => app_model.desired_state,
        'total_desired_instances' => 3,
        'created_at' => iso8601,
        'updated_at' => nil,
        'environment_variables' => environment_variables,
        '_links' => {
          'self'            => { 'href' => "/v3/apps/#{guid}" },
          'processes'       => { 'href' => "/v3/apps/#{guid}/processes" },
          'packages'        => { 'href' => "/v3/apps/#{guid}/packages" },
          'space'           => { 'href' => "/v2/spaces/#{space_guid}" },
          'desired_droplet' => { 'href' => "/v3/droplets/#{desired_droplet_guid}" },
          'start'           => { 'href' => "/v3/apps/#{guid}/start", 'method' => 'PUT' },
          'stop'           => { 'href' => "/v3/apps/#{guid}/stop", 'method' => 'PUT' },
          'assign_current_droplet' => { 'href' => "/v3/apps/#{app_model.guid}/current_droplet", 'method' => 'PUT' }
        }
      }

      parsed_response = MultiJson.load(response_body)
      expect(response_status).to eq(200)
      expect(parsed_response).to be_a_response_like(expected_response)
    end
  end

  post '/v3/apps' do
    let(:space) { VCAP::CloudController::Space.make }
    let(:space_guid) { space.guid }
    let(:name) { 'my_app' }
    let(:environment_variables) { { 'open' => 'source' } }

    before do
      space.organization.add_user(user)
      space.add_developer(user)
    end

    parameter :name, 'Name of the App', required: true
    parameter :space_guid, 'GUID of associated Space', required: true
    parameter :environment_variables, 'Environment variables to be used for the App when running', required: false

    let(:raw_post) { MultiJson.dump(params, pretty: true) }

    example 'Create an App' do
      expect {
        do_request_with_error_handling
      }.to change { VCAP::CloudController::AppModel.count }.by(1)

      created_app       = VCAP::CloudController::AppModel.last
      expected_guid     = created_app.guid
      expected_response = {
        'name'   => name,
        'guid'   => expected_guid,
        'desired_state' => 'STOPPED',
        'total_desired_instances' => 0,
        'created_at' => iso8601,
        'updated_at' => nil,
        'environment_variables' => environment_variables,
        '_links' => {
          'self'      => { 'href' => "/v3/apps/#{expected_guid}" },
          'processes' => { 'href' => "/v3/apps/#{expected_guid}/processes" },
          'packages'  => { 'href' => "/v3/apps/#{expected_guid}/packages" },
          'space'     => { 'href' => "/v2/spaces/#{space_guid}" },
          'start'     => { 'href' => "/v3/apps/#{expected_guid}/start", 'method' => 'PUT' },
          'stop'      => { 'href' => "/v3/apps/#{expected_guid}/stop", 'method' => 'PUT' },
          'assign_current_droplet' => { 'href' => "/v3/apps/#{expected_guid}/current_droplet", 'method' => 'PUT' }
        }
      }

      parsed_response = MultiJson.load(response_body)
      expect(response_status).to eq(201)
      expect(parsed_response).to be_a_response_like(expected_response)
      event = VCAP::CloudController::Event.last
      expect(event.values).to include({
        type: 'audit.app.create',
        actee: expected_guid,
        actee_type: 'v3-app',
        actee_name: name,
        actor: user.guid,
        actor_type: 'user',
        space_guid: space_guid,
        organization_guid: space.organization.guid,
      })
    end
  end

  patch '/v3/apps/:guid' do
    let(:space) { VCAP::CloudController::Space.make }
    let(:space_guid) { space.guid }
    let(:droplet) { VCAP::CloudController::DropletModel.make(app_guid: guid) }
    let(:app_model) { VCAP::CloudController::AppModel.make(name: 'original_name', space_guid: space_guid) }

    before do
      space.organization.add_user(user)
      space.add_developer(user)
    end

    parameter :name, 'Name of the App'
    parameter :environment_variables, 'Environment variables to be used for the App when running'

    let(:name) { 'new_name' }
    let(:environment_variables) do
      {
        'MY_ENV_VAR' => 'foobar',
        'FOOBAR' => 'MY_ENV_VAR'
      }
    end
    let(:guid) { app_model.guid }

    let(:raw_post) { MultiJson.dump(params, pretty: true) }

    example 'Updating an App' do
      do_request_with_error_handling

      app_model.reload
      expected_response = {
        'name'   => name,
        'guid'   => app_model.guid,
        'desired_state' => app_model.desired_state,
        'total_desired_instances' => 0,
        'created_at' => iso8601,
        'updated_at' => iso8601,
        'environment_variables' => environment_variables,
        '_links' => {
          'self'            => { 'href' => "/v3/apps/#{app_model.guid}" },
          'processes'       => { 'href' => "/v3/apps/#{app_model.guid}/processes" },
          'packages'        => { 'href' => "/v3/apps/#{app_model.guid}/packages" },
          'space'           => { 'href' => "/v2/spaces/#{space_guid}" },
          'start'     => { 'href' => "/v3/apps/#{app_model.guid}/start", 'method' => 'PUT' },
          'stop'      => { 'href' => "/v3/apps/#{app_model.guid}/stop", 'method' => 'PUT' },
          'assign_current_droplet' => { 'href' => "/v3/apps/#{app_model.guid}/current_droplet", 'method' => 'PUT' }
        }
      }

      parsed_response = MultiJson.load(response_body)
      expect(response_status).to eq(200)
      expect(parsed_response).to be_a_response_like(expected_response)
      event = VCAP::CloudController::Event.last
      expect(event.values).to include({
        type: 'audit.app.update',
        actee: app_model.guid,
        actee_type: 'v3-app',
        actee_name: name,
        actor: user.guid,
        actor_type: 'user',
        space_guid: space_guid,
        organization_guid: space.organization.guid
      })
      expect(event.metadata['request']).to eq({ 'name' => 'new_name', 'environment_variables' => 'PRIVATE DATA HIDDEN' })
    end
  end

  delete '/v3/apps/:guid' do
    let!(:app_model) { VCAP::CloudController::AppModel.make }
    let!(:package) { VCAP::CloudController::PackageModel.make(app_guid: guid) }
    let!(:droplet) { VCAP::CloudController::DropletModel.make(package_guid: package.guid, app_guid: guid) }
    let!(:process) { VCAP::CloudController::AppFactory.make(app_guid: guid, space_guid: space_guid) }
    let(:guid) { app_model.guid }
    let(:space_guid) { app_model.space_guid }
    let(:space) { VCAP::CloudController::Space.find(guid: space_guid) }

    before do
      space.organization.add_user(user)
      space.add_developer(user)
    end

    example 'Delete an App' do
      do_request_with_error_handling
      expect(response_status).to eq(204)
      expect { app_model.refresh }.to raise_error Sequel::Error, 'Record not found'
      expect { package.refresh }.to raise_error Sequel::Error, 'Record not found'
      expect { droplet.refresh }.to raise_error Sequel::Error, 'Record not found'
      expect { process.refresh }.to raise_error Sequel::Error, 'Record not found'
      event = VCAP::CloudController::Event.last(2).first
      expect(event.values).to include({
        type: 'audit.app.delete-request',
        actee: app_model.guid,
        actee_type: 'v3-app',
        actee_name: app_model.name,
        actor: user.guid,
        actor_type: 'user',
        space_guid: space_guid,
        organization_guid: space.organization.guid
      })
    end
  end

  put '/v3/apps/:guid/start' do
    let(:space) { VCAP::CloudController::Space.make }
    let(:space_guid) { space.guid }
    let(:droplet) { VCAP::CloudController::DropletModel.make(app_guid: guid) }
    let(:droplet_guid) { droplet.guid }

    let(:app_model) do
      VCAP::CloudController::AppModel.make(name: 'original_name', space_guid: space_guid, desired_state: 'STOPPED')
    end

    before do
      space.organization.add_user(user)
      space.add_developer(user)
      app_model.update(desired_droplet_guid: droplet_guid)
    end

    let(:guid) { app_model.guid }

    let(:raw_post) { MultiJson.dump(params, pretty: true) }

    example 'Starting an App' do
      do_request_with_error_handling

      expected_response = {
        'name'   => app_model.name,
        'guid'   => app_model.guid,
        'desired_state'   => 'STARTED',
        'total_desired_instances' => 0,
        'created_at' => iso8601,
        'updated_at' => iso8601,
        'environment_variables' => {},
        '_links' => {
          'self'            => { 'href' => "/v3/apps/#{app_model.guid}" },
          'processes'       => { 'href' => "/v3/apps/#{app_model.guid}/processes" },
          'packages'        => { 'href' => "/v3/apps/#{app_model.guid}/packages" },
          'space'           => { 'href' => "/v2/spaces/#{space_guid}" },
          'desired_droplet' => { 'href' => "/v3/droplets/#{droplet_guid}" },
          'start'           => { 'href' => "/v3/apps/#{app_model.guid}/start", 'method' => 'PUT' },
          'stop'            => { 'href' => "/v3/apps/#{app_model.guid}/stop", 'method' => 'PUT' },
          'assign_current_droplet' => { 'href' => "/v3/apps/#{app_model.guid}/current_droplet", 'method' => 'PUT' }
        }
      }

      parsed_response = MultiJson.load(response_body)
      expect(response_status).to eq(200)
      expect(parsed_response).to be_a_response_like(expected_response)
      event = VCAP::CloudController::Event.last
      expect(event.values).to include({
        type: 'audit.app.start',
        actee: guid,
        actee_type: 'v3-app',
        actee_name: app_model.name,
        actor: user.guid,
        actor_type: 'user',
        space_guid: space_guid,
        organization_guid: space.organization.guid,
      })
    end
  end

  put '/v3/apps/:guid/stop' do
    let(:space) { VCAP::CloudController::Space.make }
    let(:space_guid) { space.guid }
    let(:droplet) { VCAP::CloudController::DropletModel.make(app_guid: guid) }
    let(:droplet_guid) { droplet.guid }

    let(:app_model) do
      VCAP::CloudController::AppModel.make(name: 'original_name', space_guid: space_guid, desired_state: 'STARTED')
    end

    before do
      space.organization.add_user(user)
      space.add_developer(user)
      app_model.update(desired_droplet_guid: droplet_guid)
    end

    let(:guid) { app_model.guid }

    let(:raw_post) { MultiJson.dump(params, pretty: true) }

    example 'Stopping an App' do
      do_request_with_error_handling

      expected_response = {
        'name'   => app_model.name,
        'guid'   => app_model.guid,
        'desired_state'   => 'STOPPED',
        'total_desired_instances' => 0,
        'created_at' => iso8601,
        'updated_at' => iso8601,
        'environment_variables' => {},
        '_links' => {
          'self'            => { 'href' => "/v3/apps/#{app_model.guid}" },
          'processes'       => { 'href' => "/v3/apps/#{app_model.guid}/processes" },
          'packages'        => { 'href' => "/v3/apps/#{app_model.guid}/packages" },
          'space'           => { 'href' => "/v2/spaces/#{space_guid}" },
          'desired_droplet' => { 'href' => "/v3/droplets/#{droplet_guid}" },
          'start'           => { 'href' => "/v3/apps/#{app_model.guid}/start", 'method' => 'PUT' },
          'stop'            => { 'href' => "/v3/apps/#{app_model.guid}/stop", 'method' => 'PUT' },
          'assign_current_droplet' => { 'href' => "/v3/apps/#{app_model.guid}/current_droplet", 'method' => 'PUT' }
        }
      }

      parsed_response = MultiJson.load(response_body)
      expect(response_status).to eq(200)
      expect(parsed_response).to be_a_response_like(expected_response)
      event = VCAP::CloudController::Event.last
      expect(event.values).to include({
        type: 'audit.app.stop',
        actee: guid,
        actee_type: 'v3-app',
        actee_name: app_model.name,
        actor: user.guid,
        actor_type: 'user',
        space_guid: space_guid,
        organization_guid: space.organization.guid,
      })
    end
  end

  get '/v3/apps/:guid/env' do
    let(:space_name) { 'some_space' }
    let(:space) { VCAP::CloudController::Space.make(name: space_name) }
    let(:space_guid) { space.guid }

    let(:app_model) do
      VCAP::CloudController::AppModel.make(
        name: 'app_name',
        space_guid: space_guid,
        environment_variables: {
          'SOME_KEY' => 'some_val'
        }
      )
    end

    before do
      space.organization.add_user(user)
      space.add_developer(user)
      VCAP::CloudController::EnvironmentVariableGroup.make name: :staging, environment_json: { STAGING_ENV: 'staging_value' }
      VCAP::CloudController::EnvironmentVariableGroup.make name: :running, environment_json: { RUNNING_ENV: 'running_value' }
    end

    let(:guid) { app_model.guid }

    let(:raw_post) { MultiJson.dump(params, pretty: true) }

    example 'getting the env of an app' do
      do_request_with_error_handling

      expected_response = {
        'staging_env_json' => {
          'STAGING_ENV' => 'staging_value'
        },
        'running_env_json' => {
          'RUNNING_ENV' => 'running_value'
        },
        'environment_variables' => {
          'SOME_KEY' => 'some_val'
        },
        # 'system_env_json' => {
        #   'VCAP_SERVICES' => "NOT YET IMPLEMENTED"
        # },
        'application_env_json' =>   {
          'VCAP_APPLICATION' =>     {
            'limits' => {
              # 'mem' => 1024,
              # 'disk' => 1024,
              'fds' => 16384
            },
            # 'application_version' => 'a4340b70-5fe6-425f-a319-f6af377ea26b',
            'application_name' => 'app_name',
            'application_uris' => [],
            # 'version' => 'a4340b70-5fe6-425f-a319-f6af377ea26b',
            'name' => 'app_name',
            'space_name' => space_name,
            'space_id' => space_guid,
            'uris' => [],
            'users' => nil
          }
        }
      }

      parsed_response = MultiJson.load(response_body)
      expect(response_status).to eq(200)
      expect(parsed_response).to match(expected_response)
    end
  end

  put '/v3/apps/:guid/current_droplet' do
    let(:space) { VCAP::CloudController::Space.make }
    let(:space_guid) { space.guid }
    let(:procfile) { 'web: start the app' }
    let(:droplet) { VCAP::CloudController::DropletModel.make(app_guid: guid, procfile: procfile) }
    let(:app_model) { VCAP::CloudController::AppModel.make(name: 'name1', space_guid: space_guid) }

    before do
      space.organization.add_user(user)
      space.add_developer(user)
    end

    parameter :desired_droplet_guid, 'GUID of the Droplet to be used for the App'

    let(:desired_droplet_guid) { droplet.guid }
    let(:guid) { app_model.guid }

    let(:raw_post) { MultiJson.dump(params, pretty: true) }

    example 'Assigning a droplet as a an Apps current droplet' do
      do_request_with_error_handling

      expected_response = {
        'name'   => app_model.name,
        'guid'   => app_model.guid,
        'desired_state' => app_model.desired_state,
        'total_desired_instances' => 1,
        'environment_variables' => {},
        'created_at' => iso8601,
        'updated_at' => iso8601,
        '_links' => {
          'self'            => { 'href' => "/v3/apps/#{app_model.guid}" },
          'processes'       => { 'href' => "/v3/apps/#{app_model.guid}/processes" },
          'packages'        => { 'href' => "/v3/apps/#{app_model.guid}/packages" },
          'space'           => { 'href' => "/v2/spaces/#{space_guid}" },
          'desired_droplet' => { 'href' => "/v3/droplets/#{desired_droplet_guid}" },
          'start'     => { 'href' => "/v3/apps/#{app_model.guid}/start", 'method' => 'PUT' },
          'stop'      => { 'href' => "/v3/apps/#{app_model.guid}/stop", 'method' => 'PUT' },
          'assign_current_droplet' => { 'href' => "/v3/apps/#{app_model.guid}/current_droplet", 'method' => 'PUT' }
        }
      }

      parsed_response = MultiJson.load(response_body)
      expect(response_status).to eq(200)
      expect(parsed_response).to match(expected_response)
      event = VCAP::CloudController::Event.where(actor: user.guid).first
      expect(event.values).to include({
        type: 'audit.app.update',
        actee: app_model.guid,
        actee_type: 'v3-app',
        actee_name: app_model.name,
        actor: user.guid,
        actor_type: 'user',
        space_guid: space_guid,
        space_id: space.id,
        organization_guid: space.organization.guid
      })
      expect(event.metadata).to eq({ 'request' => { 'desired_droplet_guid' => droplet.guid } })
      expect(app_model.reload.processes).not_to be_empty
    end
  end
end
