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

      it "lists all apps" do
        get "/v3/apps", {per_page: per_page, order_by: order_by}, user_header

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

          get "/v3/apps", {per_page: per_page, space_guids: space_guids, names: names, order_by: order_by},  admin_header

          parsed_response = MultiJson.load(last_response.body)
          expect(last_response.status).to eq(200)
          expect(parsed_response['resources'].map { |r| r['name'] }).to eq(['my_app1', 'my_app1'])
          expect(parsed_response['pagination']).to eq(expected_pagination)
        end
      end
    end
  end
end
