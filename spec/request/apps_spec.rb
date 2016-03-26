ENV['RACK_ENV'] = 'test'
require 'rack/test'
require 'spec_helper'

describe 'Apps' do
  include Rack::Test::Methods
  include ControllerHelpers

  def app
    test_config     = TestConfig.config
    request_metrics = VCAP::CloudController::Metrics::RequestMetrics.new
    VCAP::CloudController::RackAppBuilder.new.build test_config, request_metrics
  end

  let(:user) { VCAP::CloudController::User.make }
  let(:user_header) { headers_for(user) }

  describe 'GET /v3/apps' do
    describe 'list all of the apps' do
      let(:name1) { 'my_app1' }
      let(:name2) { 'my_app2' }
      let(:name3) { 'my_app3' }
      let(:environment_variables) { { 'magic' => 'beautiful' } }
      let(:buildpack) { VCAP::CloudController::Buildpack.make }
      let(:lifecycle) { { 'type' => 'buildpack', 'data' => { 'buildpack' => buildpack.name } } }
      let!(:app_model1) { VCAP::CloudController::AppModel.make(name: name1, space_guid: space.guid, created_at: Time.at(1)) }
      let!(:app_model2) { VCAP::CloudController::AppModel.make(name: name2, space_guid: space.guid, created_at: Time.at(2)) }
      let!(:app_model3) { VCAP::CloudController::AppModel.make(
        name:                  name3,
        space_guid:            space.guid,
        environment_variables: environment_variables,
        created_at:            Time.at(3),
      )
      }
      let!(:app_model4) { VCAP::CloudController::AppModel.make(space_guid: VCAP::CloudController::Space.make.guid) }
      let(:space) { VCAP::CloudController::Space.make }
      let(:page) { 1 }
      let(:per_page) { 2 }
      let(:order_by) { '-created_at' }

      before do
        space.organization.add_user user
        space.add_developer user

        VCAP::CloudController::BuildpackLifecycleDataModel.make(app: app_model1)
        VCAP::CloudController::BuildpackLifecycleDataModel.make(app: app_model2)
        VCAP::CloudController::BuildpackLifecycleDataModel.make(app: app_model3)
        VCAP::CloudController::BuildpackLifecycleDataModel.make(app: app_model4)
      end

      it 'lists all apps' do
        get '/v3/apps', { per_page: per_page, order_by: order_by }, user_header

        expected_response = {
          'pagination' => {
            'total_results' => 3,
            'first'         => { 'href' => "/v3/apps?order_by=#{order_by}&page=1&per_page=2" },
            'last'          => { 'href' => "/v3/apps?order_by=#{order_by}&page=2&per_page=2" },
            'next'          => { 'href' => "/v3/apps?order_by=#{order_by}&page=2&per_page=2" },
            'previous'      => nil,
          },
          'resources' => [
            {
              'name'                    => name3,
              'guid'                    => app_model3.guid,
              'desired_state'           => app_model3.desired_state,
              'total_desired_instances' => 0,
              'lifecycle'               => {
                'type' => 'buildpack',
                'data' => {
                  'buildpack' => app_model3.lifecycle_data.buildpack,
                  'stack'     => app_model3.lifecycle_data.stack,
                }
              },
              'created_at'              => iso8601,
              'updated_at'              => nil,
              'environment_variables'   => environment_variables,
              'links'                   => {
                'self'                   => { 'href' => "/v3/apps/#{app_model3.guid}" },
                'processes'              => { 'href' => "/v3/apps/#{app_model3.guid}/processes" },
                'packages'               => { 'href' => "/v3/apps/#{app_model3.guid}/packages" },
                'space'                  => { 'href' => "/v2/spaces/#{space.guid}" },
                'droplets'               => { 'href' => "/v3/apps/#{app_model3.guid}/droplets" },
                'tasks'                  => { 'href' => "/v3/apps/#{app_model3.guid}/tasks" },
                'route_mappings'         => { 'href' => "/v3/apps/#{app_model3.guid}/route_mappings" },
                'start'                  => { 'href' => "/v3/apps/#{app_model3.guid}/start", 'method' => 'PUT' },
                'stop'                   => { 'href' => "/v3/apps/#{app_model3.guid}/stop", 'method' => 'PUT' },
                'assign_current_droplet' => { 'href' => "/v3/apps/#{app_model3.guid}/current_droplet", 'method' => 'PUT' }
              }
            },
            {
              'name'                    => name2,
              'guid'                    => app_model2.guid,
              'desired_state'           => app_model2.desired_state,
              'total_desired_instances' => 0,
              'lifecycle'               => {
                'type' => 'buildpack',
                'data' => {
                  'buildpack' => app_model2.lifecycle_data.buildpack,
                  'stack'     => app_model2.lifecycle_data.stack,
                }
              },
              'created_at'              => iso8601,
              'updated_at'              => nil,
              'environment_variables'   => {},
              'links'                   => {
                'self'                   => { 'href' => "/v3/apps/#{app_model2.guid}" },
                'processes'              => { 'href' => "/v3/apps/#{app_model2.guid}/processes" },
                'packages'               => { 'href' => "/v3/apps/#{app_model2.guid}/packages" },
                'space'                  => { 'href' => "/v2/spaces/#{space.guid}" },
                'droplets'               => { 'href' => "/v3/apps/#{app_model2.guid}/droplets" },
                'tasks'                  => { 'href' => "/v3/apps/#{app_model2.guid}/tasks" },
                'route_mappings'         => { 'href' => "/v3/apps/#{app_model2.guid}/route_mappings" },
                'start'                  => { 'href' => "/v3/apps/#{app_model2.guid}/start", 'method' => 'PUT' },
                'stop'                   => { 'href' => "/v3/apps/#{app_model2.guid}/stop", 'method' => 'PUT' },
                'assign_current_droplet' => { 'href' => "/v3/apps/#{app_model2.guid}/current_droplet", 'method' => 'PUT' }
              }
            }
          ]
        }

        parsed_response = MultiJson.load(last_response.body)

        expect(last_response.status).to eq(200)
        expect(parsed_response).to be_a_response_like(expected_response)
      end

      context 'faceted search' do
        let(:app_model5) { VCAP::CloudController::AppModel.make(name: name1, space_guid: VCAP::CloudController::Space.make.guid) }
        let!(:app_model6) { VCAP::CloudController::AppModel.make(name: name1, space_guid: VCAP::CloudController::Space.make.guid) }
        let(:per_page) { 2 }
        let(:space_guids) { [app_model5.space_guid, space.guid, app_model6.space_guid].join(',') }
        let(:names) { [name1].join(',') }
        let(:admin_header) { headers_for(user, scopes: %w(cloud_controller.admin)) }

        before do
          VCAP::CloudController::BuildpackLifecycleDataModel.make(app: app_model5)
          VCAP::CloudController::BuildpackLifecycleDataModel.make(app: app_model6)
        end

        it 'filters Apps by guids, names, spaces, and organizations' do
          expected_pagination = {
            'total_results' => 3,
            'first'         => { 'href' => "/v3/apps?names=#{name1}&order_by=#{order_by}&page=1&per_page=2&space_guids=#{CGI.escape(space_guids)}" },
            'last'          => { 'href' => "/v3/apps?names=#{name1}&order_by=#{order_by}&page=2&per_page=2&space_guids=#{CGI.escape(space_guids)}" },
            'next'          => { 'href' => "/v3/apps?names=#{name1}&order_by=#{order_by}&page=2&per_page=2&space_guids=#{CGI.escape(space_guids)}" },
            'previous'      => nil
          }

          get '/v3/apps', { per_page: per_page, space_guids: space_guids, names: names, order_by: order_by }, admin_header

          parsed_response = MultiJson.load(last_response.body)
          expect(last_response.status).to eq(200)
          expect(parsed_response['resources'].map { |r| r['name'] }).to eq(['my_app1', 'my_app1'])
          expect(parsed_response['pagination']).to eq(expected_pagination)
        end
      end
    end
  end

  describe 'GET /v3/apps/:guid' do
    let(:droplet_guid) { 'a-droplet-guid' }
    let(:environment_variables) { { 'unicorn' => 'horn' } }
    let(:buildpack) { VCAP::CloudController::Buildpack.make }
    let(:app_model) { VCAP::CloudController::AppModel.make(
      name:                  name,
      droplet_guid:          droplet_guid,
      environment_variables: environment_variables
    )
    }
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

      VCAP::CloudController::BuildpackLifecycleDataModel.make(app: app_model)
    end

    it 'get a specific app' do
      # do_request_with_error_handling
      get "/v3/apps/#{guid}", {}, user_header

      expected_response = {
        'name'                    => name,
        'guid'                    => guid,
        'desired_state'           => app_model.desired_state,
        'total_desired_instances' => 3,
        'created_at'              => iso8601,
        'updated_at'              => nil,
        'environment_variables'   => environment_variables,
        'lifecycle'               => {
          'type' => 'buildpack',
          'data' => {
            'buildpack' => app_model.lifecycle_data.buildpack,
            'stack'     => app_model.lifecycle_data.stack,
          }
        },
        'links' => {
          'self'                   => { 'href' => "/v3/apps/#{guid}" },
          'processes'              => { 'href' => "/v3/apps/#{guid}/processes" },
          'packages'               => { 'href' => "/v3/apps/#{guid}/packages" },
          'space'                  => { 'href' => "/v2/spaces/#{space_guid}" },
          'droplet'                => { 'href' => "/v3/droplets/#{droplet_guid}" },
          'droplets'               => { 'href' => "/v3/apps/#{guid}/droplets" },
          'tasks'                  => { 'href' => "/v3/apps/#{guid}/tasks" },
          'route_mappings'         => { 'href' => "/v3/apps/#{guid}/route_mappings" },
          'start'                  => { 'href' => "/v3/apps/#{guid}/start", 'method' => 'PUT' },
          'stop'                   => { 'href' => "/v3/apps/#{guid}/stop", 'method' => 'PUT' },
          'assign_current_droplet' => { 'href' => "/v3/apps/#{app_model.guid}/current_droplet", 'method' => 'PUT' }
        }
      }

      parsed_response = MultiJson.load(last_response.body)
      expect(last_response.status).to eq(200)
      expect(parsed_response).to be_a_response_like(expected_response)
    end
  end

  describe 'DELETE /v3/apps/guid' do
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

    it 'Delete an App' do
      delete "/v3/apps/#{guid}", {}, headers_for(user)
      expect(last_response.status).to eq(204)
      expect { app_model.refresh }.to raise_error Sequel::Error, 'Record not found'
      expect { package.refresh }.to raise_error Sequel::Error, 'Record not found'
      expect { droplet.refresh }.to raise_error Sequel::Error, 'Record not found'
      expect { process.refresh }.to raise_error Sequel::Error, 'Record not found'
      event = VCAP::CloudController::Event.last(2).first
      expect(event.values).to include({
            type:              'audit.app.delete-request',
            actee:             app_model.guid,
            actee_type:        'v3-app',
            actee_name:        app_model.name,
            actor:             user.guid,
            actor_type:        'user',
            space_guid:        space_guid,
            organization_guid: space.organization.guid
          })
    end
  end

  describe 'POST /v3/apps' do
    let(:space) { VCAP::CloudController::Space.make }
    let(:space_guid) { space.guid }
    let(:name) { 'my_app' }
    let(:buildpack) { VCAP::CloudController::Buildpack.make.name }
    let(:environment_variables) { { 'open' => 'source' } }
    let(:lifecycle) { { 'type' => 'buildpack', 'data' => { 'stack' => nil, 'buildpack' => buildpack } } }
    let(:relationships) { { 'space' => { 'guid' => space_guid } } }

    before do
      space.organization.add_user(user)
      space.add_developer(user)
    end

    it 'creates an app' do
      expect {
        post '/v3/apps', { name: name, environment_variables: environment_variables, lifecycle: lifecycle, relationships: relationships }, user_header
      }.to change { VCAP::CloudController::AppModel.count }.by(1)

      created_app       = VCAP::CloudController::AppModel.last
      expected_guid     = created_app.guid
      expected_response = {
        'name'                    => name,
        'guid'                    => expected_guid,
        'desired_state'           => 'STOPPED',
        'total_desired_instances' => 0,
        'lifecycle'               => {
          'type' => 'buildpack',
          'data' => {
            'buildpack' => created_app.lifecycle_data.buildpack,
            'stack'     => created_app.lifecycle_data.stack,
          }
        },
        'created_at'              => iso8601,
        'updated_at'              => nil,
        'environment_variables'   => environment_variables,
        'links'                   => {
          'self'                   => { 'href' => "/v3/apps/#{expected_guid}" },
          'processes'              => { 'href' => "/v3/apps/#{expected_guid}/processes" },
          'packages'               => { 'href' => "/v3/apps/#{expected_guid}/packages" },
          'space'                  => { 'href' => "/v2/spaces/#{space_guid}" },
          'droplets'               => { 'href' => "/v3/apps/#{expected_guid}/droplets" },
          'tasks'                  => { 'href' => "/v3/apps/#{expected_guid}/tasks" },
          'route_mappings'         => { 'href' => "/v3/apps/#{expected_guid}/route_mappings" },
          'start'                  => { 'href' => "/v3/apps/#{expected_guid}/start", 'method' => 'PUT' },
          'stop'                   => { 'href' => "/v3/apps/#{expected_guid}/stop", 'method' => 'PUT' },
          'assign_current_droplet' => { 'href' => "/v3/apps/#{expected_guid}/current_droplet", 'method' => 'PUT' }
        }
      }

      parsed_response = MultiJson.load(last_response.body)
      expect(last_response.status).to eq(201)
      expect(parsed_response).to be_a_response_like(expected_response)
      event = VCAP::CloudController::Event.last
      expect(event.values).to include({
            type:              'audit.app.create',
            actee:             expected_guid,
            actee_type:        'v3-app',
            actee_name:        name,
            actor:             user.guid,
            actor_type:        'user',
            space_guid:        space_guid,
            organization_guid: space.organization.guid,
          })
    end

    describe 'Docker app' do
      let(:lifecycle) { { 'type' => 'docker', 'data' => {} } }

      before do
        VCAP::CloudController::FeatureFlag.make(name: 'diego_docker', enabled: true, error_message: nil)
      end

      it 'create a docker app' do
        expect {
          post '/v3/apps',
            { name: name,
              environment_variables: environment_variables,
              lifecycle: lifecycle,
              relationships: relationships }.to_json,
            headers_for(user).merge({ 'CONTENT_TYPE' => 'application/json' })
        }.to change { VCAP::CloudController::AppModel.count }.by(1)

        created_app       = VCAP::CloudController::AppModel.last
        expected_guid     = created_app.guid
        expected_response = {
          'name'                    => name,
          'guid'                    => expected_guid,
          'desired_state'           => 'STOPPED',
          'total_desired_instances' => 0,
          'lifecycle'               => {
            'type' => 'docker',
            'data' => {}
          },
          'created_at'              => iso8601,
          'updated_at'              => nil,
          'environment_variables'   => environment_variables,
          'links'                   => {
            'self'                   => { 'href' => "/v3/apps/#{expected_guid}" },
            'processes'              => { 'href' => "/v3/apps/#{expected_guid}/processes" },
            'packages'               => { 'href' => "/v3/apps/#{expected_guid}/packages" },
            'space'                  => { 'href' => "/v2/spaces/#{space_guid}" },
            'droplets'               => { 'href' => "/v3/apps/#{expected_guid}/droplets" },
            'tasks'                  => { 'href' => "/v3/apps/#{expected_guid}/tasks" },
            'route_mappings'         => { 'href' => "/v3/apps/#{expected_guid}/route_mappings" },
            'start'                  => { 'href' => "/v3/apps/#{expected_guid}/start", 'method' => 'PUT' },
            'stop'                   => { 'href' => "/v3/apps/#{expected_guid}/stop", 'method' => 'PUT' },
            'assign_current_droplet' => { 'href' => "/v3/apps/#{expected_guid}/current_droplet", 'method' => 'PUT' }
          }
        }

        parsed_response = MultiJson.load(last_response.body)
        expect(last_response.status).to eq(201)
        expect(parsed_response).to be_a_response_like(expected_response)
        event = VCAP::CloudController::Event.last
        expect(event.values).to include({
              type:              'audit.app.create',
              actee:             expected_guid,
              actee_type:        'v3-app',
              actee_name:        name,
              actor:             user.guid,
              actor_type:        'user',
              space_guid:        space_guid,
              organization_guid: space.organization.guid,
            })
      end
    end
  end

  describe 'PATCH /v3/apps/:guid' do
    let(:space) { VCAP::CloudController::Space.make }
    let(:space_guid) { space.guid }
    let(:droplet) { VCAP::CloudController::DropletModel.make(app_guid: guid) }
    let(:buildpack) { 'http://gitwheel.org/my-app' }
    let(:app_model) { VCAP::CloudController::AppModel.make(name: 'original_name', space_guid: space_guid) }

    let(:stack) { VCAP::CloudController::Stack.make(name: 'redhat') }
    let(:lifecycle) { { 'type' => 'buildpack', 'data' => { 'buildpack' => buildpack, 'stack' => stack.name } } }

    before do
      space.organization.add_user(user)
      space.add_developer(user)
      VCAP::CloudController::BuildpackLifecycleDataModel.make(app: app_model, stack: VCAP::CloudController::Stack.default.name, buildpack: 'og-buildpack')
    end


    let(:name) { 'new_name' }
    let(:environment_variables) do
      {
        'MY_ENV_VAR' => 'foobar',
        'FOOBAR'     => 'MY_ENV_VAR'
      }
    end
    let(:guid) { app_model.guid }

    it 'updates an app' do
      patch "/v3/apps/#{guid}", { name: name, environment_variables: environment_variables, lifecycle: lifecycle }, headers_for(user)
      app_model.reload
      expected_response = {
        'name'                    => name,
        'guid'                    => app_model.guid,
        'desired_state'           => app_model.desired_state,
        'total_desired_instances' => 0,
        'lifecycle'               => {
          'type' => 'buildpack',
          'data' => {
            'buildpack' => buildpack,
            'stack'     => stack.name,
          }
        },
        'created_at'              => iso8601,
        'updated_at'              => iso8601,
        'environment_variables'   => environment_variables,
        'links'                   => {
          'self'                   => { 'href' => "/v3/apps/#{app_model.guid}" },
          'processes'              => { 'href' => "/v3/apps/#{app_model.guid}/processes" },
          'packages'               => { 'href' => "/v3/apps/#{app_model.guid}/packages" },
          'space'                  => { 'href' => "/v2/spaces/#{space_guid}" },
          'droplets'               => { 'href' => "/v3/apps/#{app_model.guid}/droplets" },
          'tasks'                  => { 'href' => "/v3/apps/#{app_model.guid}/tasks" },
          'route_mappings'         => { 'href' => "/v3/apps/#{app_model.guid}/route_mappings" },
          'start'                  => { 'href' => "/v3/apps/#{app_model.guid}/start", 'method' => 'PUT' },
          'stop'                   => { 'href' => "/v3/apps/#{app_model.guid}/stop", 'method' => 'PUT' },
          'assign_current_droplet' => { 'href' => "/v3/apps/#{app_model.guid}/current_droplet", 'method' => 'PUT' }
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
        actee_name:        name,
        actor:             user.guid,
        actor_type:        'user',
        space_guid:        space_guid,
        organization_guid: space.organization.guid
        })

      metadata_request = { 'name' => 'new_name', 'environment_variables' => 'PRIVATE DATA HIDDEN',
          'lifecycle' => { 'type' => 'buildpack', 'data' => { 'buildpack' => buildpack, 'stack' => stack.name } } }
      expect(event.metadata['request']).to eq(metadata_request)
    end
  end
end
