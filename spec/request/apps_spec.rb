require 'spec_helper'
require 'actions/process_create_from_app_droplet'

RSpec.describe 'Apps' do
  let(:user) { VCAP::CloudController::User.make }
  let(:user_header) { headers_for(user, email: user_email, user_name: user_name) }
  let(:admin_header) { admin_headers_for(user) }
  let(:org) { VCAP::CloudController::Organization.make(created_at: 3.days.ago) }
  let(:space) { VCAP::CloudController::Space.make(organization: org) }
  let(:stack) { VCAP::CloudController::Stack.make }
  let(:user_email) { Sham.email }
  let(:user_name) { 'some-username' }

  before do
    space.organization.add_user(user)
    space.add_developer(user)
  end

  describe 'POST /v3/apps' do
    let(:buildpack) { VCAP::CloudController::Buildpack.make(stack: stack.name) }
    let(:create_request) do
      {
          name: 'my_app',
          environment_variables: { open: 'source' },
          lifecycle: {
              type: 'buildpack',
              data: {
                  stack: buildpack.stack,
                  buildpacks: [buildpack.name]
              }
          },
          relationships: {
              space: {
                  data: {
                      guid: space.guid
                  }
              }
          },
          metadata: {
              labels: {
                  'release' => 'stable',
                  'code.cloudfoundry.org/cloud_controller_ng' => 'awesome'
              },
              annotations: {
                  'description' => 'gud app'
              }
          }
      }
    end

    it 'creates an app' do
      post '/v3/apps', create_request.to_json, user_header
      expect(last_response.status).to eq(201)

      parsed_response = MultiJson.load(last_response.body)
      app_guid = parsed_response['guid']

      expect(VCAP::CloudController::AppModel.find(guid: app_guid)).to be
      expect(parsed_response).to be_a_response_like(
        {
            'name' => 'my_app',
            'guid' => app_guid,
            'state' => 'STOPPED',
            'lifecycle' => {
                'type' => 'buildpack',
                'data' => {
                    'buildpacks' => [buildpack.name],
                    'stack' => stack.name,
                }
            },
            'relationships' => {
                'space' => {
                    'data' => {
                        'guid' => space.guid
                    }
                }
            },
            'created_at' => iso8601,
            'updated_at' => iso8601,
            'metadata' => {
              'labels' => {
                'release' => 'stable',
                'code.cloudfoundry.org/cloud_controller_ng' => 'awesome'
              },
              'annotations' => {
                'description' => 'gud app',
              },
            },
            'links' => {
                'self' => { 'href' => "#{link_prefix}/v3/apps/#{app_guid}" },
                'processes' => { 'href' => "#{link_prefix}/v3/apps/#{app_guid}/processes" },
                'packages' => { 'href' => "#{link_prefix}/v3/apps/#{app_guid}/packages" },
                'environment_variables' => { 'href' => "#{link_prefix}/v3/apps/#{app_guid}/environment_variables" },
                'space' => { 'href' => "#{link_prefix}/v3/spaces/#{space.guid}" },
                'current_droplet' => { 'href' => "#{link_prefix}/v3/apps/#{app_guid}/droplets/current" },
                'droplets' => { 'href' => "#{link_prefix}/v3/apps/#{app_guid}/droplets" },
                'tasks' => { 'href' => "#{link_prefix}/v3/apps/#{app_guid}/tasks" },
                'route_mappings' => { 'href' => "#{link_prefix}/v3/apps/#{app_guid}/route_mappings" },
                'start' => { 'href' => "#{link_prefix}/v3/apps/#{app_guid}/actions/start", 'method' => 'POST' },
                'stop' => { 'href' => "#{link_prefix}/v3/apps/#{app_guid}/actions/stop", 'method' => 'POST' },
                'revisions' => { 'href' => "#{link_prefix}/v3/apps/#{app_guid}/revisions" },
                'deployed_revisions' => { 'href' => "#{link_prefix}/v3/apps/#{app_guid}/revisions/deployed" },
            }
        }
                                 )

      event = VCAP::CloudController::Event.last
      expect(event.values).to include({
                                          type: 'audit.app.create',
                                          actee: app_guid,
                                          actee_type: 'app',
                                          actee_name: 'my_app',
                                          actor: user.guid,
                                          actor_type: 'user',
                                          actor_name: user_email,
                                          actor_username: user_name,
                                          space_guid: space.guid,
                                          organization_guid: space.organization.guid,
                                      })
    end

    it 'creates an empty web process with the same guid as the app (so it is visible on the v2 apps api)' do
      post '/v3/apps', create_request.to_json, user_header
      expect(last_response.status).to eq(201)

      parsed_response = MultiJson.load(last_response.body)
      app_guid = parsed_response['guid']
      expect(VCAP::CloudController::AppModel.find(guid: app_guid)).to_not be_nil
      expect(VCAP::CloudController::ProcessModel.find(guid: app_guid)).to_not be_nil
    end

    describe 'Docker app' do
      before do
        VCAP::CloudController::FeatureFlag.make(name: 'diego_docker', enabled: true, error_message: nil)
      end

      it 'create a docker app' do
        create_request = {
            name: 'my_app',
            environment_variables: { open: 'source' },
            lifecycle: {
                type: 'docker',
                data: {}
            },
            relationships: {
                space: { data: { guid: space.guid } }
            }
        }

        post '/v3/apps', create_request.to_json, user_header.merge({ 'CONTENT_TYPE' => 'application/json' })

        created_app = VCAP::CloudController::AppModel.last
        expected_response = {
            'name' => 'my_app',
            'guid' => created_app.guid,
            'state' => 'STOPPED',
            'lifecycle' => {
                'type' => 'docker',
                'data' => {}
            },
            'relationships' => {
                'space' => {
                    'data' => {
                        'guid' => space.guid
                    }
                }
            },
            'created_at' => iso8601,
            'updated_at' => iso8601,
            'metadata' => { 'labels' => {}, 'annotations' => {} },
            'links' => {
                'self' => { 'href' => "#{link_prefix}/v3/apps/#{created_app.guid}" },
                'processes' => { 'href' => "#{link_prefix}/v3/apps/#{created_app.guid}/processes" },
                'packages' => { 'href' => "#{link_prefix}/v3/apps/#{created_app.guid}/packages" },
                'environment_variables' => { 'href' => "#{link_prefix}/v3/apps/#{created_app.guid}/environment_variables" },
                'space' => { 'href' => "#{link_prefix}/v3/spaces/#{space.guid}" },
                'current_droplet' => { 'href' => "#{link_prefix}/v3/apps/#{created_app.guid}/droplets/current" },
                'droplets' => { 'href' => "#{link_prefix}/v3/apps/#{created_app.guid}/droplets" },
                'tasks' => { 'href' => "#{link_prefix}/v3/apps/#{created_app.guid}/tasks" },
                'route_mappings' => { 'href' => "#{link_prefix}/v3/apps/#{created_app.guid}/route_mappings" },
                'start' => { 'href' => "#{link_prefix}/v3/apps/#{created_app.guid}/actions/start", 'method' => 'POST' },
                'stop' => { 'href' => "#{link_prefix}/v3/apps/#{created_app.guid}/actions/stop", 'method' => 'POST' },
                'revisions' => { 'href' => "#{link_prefix}/v3/apps/#{created_app.guid}/revisions" },
                'deployed_revisions' => { 'href' => "#{link_prefix}/v3/apps/#{created_app.guid}/revisions/deployed" },
            }
        }

        parsed_response = MultiJson.load(last_response.body)
        expect(last_response.status).to eq(201)
        expect(parsed_response).to be_a_response_like(expected_response)

        event = VCAP::CloudController::Event.last
        expect(event.values).to include(
          type: 'audit.app.create',
          actee: created_app.guid,
          actee_type: 'app',
          actee_name: 'my_app',
          actor: user.guid,
          actor_type: 'user',
          actor_name: user_email,
          actor_username: user_name,
          space_guid: space.guid,
          organization_guid: space.organization.guid,
        )
      end
    end
  end

  describe 'GET /v3/apps' do
    it 'returns a paginated list of apps the user has access to' do
      buildpack = VCAP::CloudController::Buildpack.make(name: 'bp-name')
      stack = VCAP::CloudController::Stack.make(name: 'stack-name')

      app_model1 = VCAP::CloudController::AppModel.make(name: 'name1', space: space, desired_state: 'STOPPED')
      app_model1.lifecycle_data.update(
        buildpacks: [buildpack.name],
        stack: stack.name
      )

      app_model2 = VCAP::CloudController::AppModel.make(
        :docker,
          name: 'name2',
          space: space,
          desired_state: 'STARTED'
      )
      VCAP::CloudController::AppModel.make(space: space)
      VCAP::CloudController::AppModel.make

      get '/v3/apps?per_page=2&include=space', nil, user_header
      expect(last_response.status).to eq(200)

      parsed_response = MultiJson.load(last_response.body)
      expect(parsed_response).to be_a_response_like(
        {
            'pagination' => {
                'total_results' => 3,
                'total_pages' => 2,
                'first' => { 'href' => "#{link_prefix}/v3/apps?include=space&page=1&per_page=2" },
                'last' => { 'href' => "#{link_prefix}/v3/apps?include=space&page=2&per_page=2" },
                'next' => { 'href' => "#{link_prefix}/v3/apps?include=space&page=2&per_page=2" },
                'previous' => nil,
            },
            'resources' => [
              {
                    'guid' => app_model1.guid,
                    'name' => 'name1',
                    'state' => 'STOPPED',
                    'lifecycle' => {
                        'type' => 'buildpack',
                        'data' => {
                            'buildpacks' => ['bp-name'],
                            'stack' => 'stack-name',
                        }
                    },
                    'relationships' => {
                        'space' => {
                            'data' => {
                                'guid' => space.guid
                            }
                        }
                    },
                    'created_at' => iso8601,
                    'updated_at' => iso8601,
                    'metadata' => { 'labels' => {}, 'annotations' => {} },
                    'links' => {
                        'self' => { 'href' => "#{link_prefix}/v3/apps/#{app_model1.guid}" },
                        'processes' => { 'href' => "#{link_prefix}/v3/apps/#{app_model1.guid}/processes" },
                        'packages' => { 'href' => "#{link_prefix}/v3/apps/#{app_model1.guid}/packages" },
                        'environment_variables' => { 'href' => "#{link_prefix}/v3/apps/#{app_model1.guid}/environment_variables" },
                        'space' => { 'href' => "#{link_prefix}/v3/spaces/#{space.guid}" },
                        'current_droplet' => { 'href' => "#{link_prefix}/v3/apps/#{app_model1.guid}/droplets/current" },
                        'droplets' => { 'href' => "#{link_prefix}/v3/apps/#{app_model1.guid}/droplets" },
                        'tasks' => { 'href' => "#{link_prefix}/v3/apps/#{app_model1.guid}/tasks" },
                        'route_mappings' => { 'href' => "#{link_prefix}/v3/apps/#{app_model1.guid}/route_mappings" },
                        'start' => { 'href' => "#{link_prefix}/v3/apps/#{app_model1.guid}/actions/start", 'method' => 'POST' },
                        'stop' => { 'href' => "#{link_prefix}/v3/apps/#{app_model1.guid}/actions/stop", 'method' => 'POST' },
                        'revisions' => { 'href' => "#{link_prefix}/v3/apps/#{app_model1.guid}/revisions" },
                        'deployed_revisions' => { 'href' => "#{link_prefix}/v3/apps/#{app_model1.guid}/revisions/deployed" },
                    }
                },
              {
                  'guid' => app_model2.guid,
                  'name' => 'name2',
                  'state' => 'STARTED',
                  'lifecycle' => {
                      'type' => 'docker',
                      'data' => {}
                  },
                  'relationships' => {
                      'space' => {
                          'data' => {
                              'guid' => space.guid
                          }
                      }
                  },
                  'created_at' => iso8601,
                  'updated_at' => iso8601,
                  'metadata' => { 'labels' => {}, 'annotations' => {} },
                  'links' => {
                      'self' => { 'href' => "#{link_prefix}/v3/apps/#{app_model2.guid}" },
                      'processes' => { 'href' => "#{link_prefix}/v3/apps/#{app_model2.guid}/processes" },
                      'packages' => { 'href' => "#{link_prefix}/v3/apps/#{app_model2.guid}/packages" },
                      'environment_variables' => { 'href' => "#{link_prefix}/v3/apps/#{app_model2.guid}/environment_variables" },
                      'space' => { 'href' => "#{link_prefix}/v3/spaces/#{space.guid}" },
                      'current_droplet' => { 'href' => "#{link_prefix}/v3/apps/#{app_model2.guid}/droplets/current" },
                      'droplets' => { 'href' => "#{link_prefix}/v3/apps/#{app_model2.guid}/droplets" },
                      'tasks' => { 'href' => "#{link_prefix}/v3/apps/#{app_model2.guid}/tasks" },
                      'route_mappings' => { 'href' => "#{link_prefix}/v3/apps/#{app_model2.guid}/route_mappings" },
                      'start' => { 'href' => "#{link_prefix}/v3/apps/#{app_model2.guid}/actions/start", 'method' => 'POST' },
                      'stop' => { 'href' => "#{link_prefix}/v3/apps/#{app_model2.guid}/actions/stop", 'method' => 'POST' },
                      'revisions' => { 'href' => "#{link_prefix}/v3/apps/#{app_model2.guid}/revisions" },
                      'deployed_revisions' => { 'href' => "#{link_prefix}/v3/apps/#{app_model2.guid}/revisions/deployed" },
                  }
              }
            ],
            'included' => {
                'spaces' => [{
                                 'guid' => space.guid,
                                 'created_at' => iso8601,
                                 'updated_at' => iso8601,
                                 'name' => space.name,
                                 'relationships' => {
                                     'organization' => {
                                         'data' => {
                                             'guid' => space.organization.guid }
                                     }
                                 },
                                 'metadata' => {
                                     'labels' => {},
                                     'annotations' => {},
                                 },
                                 'links' => {
                                     'self' => {
                                         'href' => "#{link_prefix}/v3/spaces/#{space.guid}",
                                     },
                                     'organization' => {
                                         'href' => "#{link_prefix}/v3/organizations/#{space.organization.guid}"
                                     }
                                 }
                             }]
            }
        }
                                 )
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
            'total_pages' => 1,
            'first' => { 'href' => "#{link_prefix}/v3/apps?guids=#{app_model1.guid}%2C#{app_model3.guid}&page=1&per_page=50" },
            'last' => { 'href' => "#{link_prefix}/v3/apps?guids=#{app_model1.guid}%2C#{app_model3.guid}&page=1&per_page=50" },
            'next' => nil,
            'previous' => nil
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
            'total_pages' => 1,
            'first' => { 'href' => "#{link_prefix}/v3/apps?names=name1%2Cname2&page=1&per_page=50" },
            'last' => { 'href' => "#{link_prefix}/v3/apps?names=name1%2Cname2&page=1&per_page=50" },
            'next' => nil,
            'previous' => nil
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
            'total_pages' => 1,
            'first' => { 'href' => "#{link_prefix}/v3/apps?organization_guids=#{app_model1.organization.guid}%2C#{app_model3.organization.guid}&page=1&per_page=50" },
            'last' => { 'href' => "#{link_prefix}/v3/apps?organization_guids=#{app_model1.organization.guid}%2C#{app_model3.organization.guid}&page=1&per_page=50" },
            'next' => nil,
            'previous' => nil
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
            'total_pages' => 1,
            'first' => { 'href' => "#{link_prefix}/v3/apps?page=1&per_page=50&space_guids=#{app_model1.space.guid}%2C#{app_model3.space.guid}" },
            'last' => { 'href' => "#{link_prefix}/v3/apps?page=1&per_page=50&space_guids=#{app_model1.space.guid}%2C#{app_model3.space.guid}" },
            'next' => nil,
            'previous' => nil
        }

        parsed_response = MultiJson.load(last_response.body)

        expect(last_response.status).to eq(200)
        expect(parsed_response['resources'].map { |r| r['name'] }).to eq(['name1', 'name3'])
        expect(parsed_response['pagination']).to eq(expected_pagination)
      end
    end

    context 'ordering' do
      it 'can order by name' do
        VCAP::CloudController::AppModel.make(space: space, name: 'zed')
        VCAP::CloudController::AppModel.make(space: space, name: 'alpha')
        VCAP::CloudController::AppModel.make(space: space, name: 'gamma')
        VCAP::CloudController::AppModel.make(space: space, name: 'delta')
        VCAP::CloudController::AppModel.make(space: space, name: 'theta')

        ascending = ['alpha', 'delta', 'gamma', 'theta', 'zed']
        descending = ascending.reverse

        # ASCENDING
        get '/v3/apps?order_by=name', nil, user_header
        expect(last_response.status).to eq(200)
        parsed_response = MultiJson.load(last_response.body)
        app_names = parsed_response['resources'].map { |i| i['name'] }
        expect(app_names).to eq(ascending)
        expect(parsed_response['pagination']['first']['href']).to include("order_by=#{CGI.escape('+')}name")

        # DESCENDING
        get '/v3/apps?order_by=-name', nil, user_header
        expect(last_response.status).to eq(200)
        parsed_response = MultiJson.load(last_response.body)
        app_names = parsed_response['resources'].map { |i| i['name'] }
        expect(app_names).to eq(descending)
        expect(parsed_response['pagination']['first']['href']).to include('order_by=-name')
      end
    end

    context 'labels' do
      let!(:app1) { VCAP::CloudController::AppModel.make(name: 'name1') }
      let!(:app1_label) { VCAP::CloudController::AppLabelModel.make(resource_guid: app1.guid, key_name: 'foo', value: 'bar') }

      let!(:app2) { VCAP::CloudController::AppModel.make(name: 'name2') }
      let!(:app2_label) { VCAP::CloudController::AppLabelModel.make(resource_guid: app2.guid, key_name: 'foo', value: 'funky') }
      let!(:app2__exclusive_label) { VCAP::CloudController::AppLabelModel.make(resource_guid: app2.guid, key_name: 'santa', value: 'claus') }

      let(:admin_header) { headers_for(user, scopes: %w(cloud_controller.admin)) }

      it 'returns a 200 and the filtered apps for "in" label selector' do
        get '/v3/apps?label_selector=foo in (bar)', nil, admin_header

        parsed_response = MultiJson.load(last_response.body)

        expected_pagination = {
            'total_results' => 1,
            'total_pages' => 1,
            'first' => { 'href' => "#{link_prefix}/v3/apps?label_selector=foo+in+%28bar%29&page=1&per_page=50" },
            'last' => { 'href' => "#{link_prefix}/v3/apps?label_selector=foo+in+%28bar%29&page=1&per_page=50" },
            'next' => nil,
            'previous' => nil
        }

        expect(last_response.status).to eq(200)
        expect(parsed_response['resources'].map { |r| r['guid'] }).to contain_exactly(app1.guid)
        expect(parsed_response['pagination']).to eq(expected_pagination)
      end

      it 'returns a 200 and the filtered apps for "notin" label selector' do
        get '/v3/apps?label_selector=foo notin (bar)', nil, admin_header

        parsed_response = MultiJson.load(last_response.body)

        expected_pagination = {
            'total_results' => 1,
            'total_pages' => 1,
            'first' => { 'href' => "#{link_prefix}/v3/apps?label_selector=foo+notin+%28bar%29&page=1&per_page=50" },
            'last' => { 'href' => "#{link_prefix}/v3/apps?label_selector=foo+notin+%28bar%29&page=1&per_page=50" },
            'next' => nil,
            'previous' => nil
        }

        expect(last_response.status).to eq(200)
        expect(parsed_response['resources'].map { |r| r['guid'] }).to contain_exactly(app2.guid)
        expect(parsed_response['pagination']).to eq(expected_pagination)
      end

      it 'returns a 200 and the filtered apps for "=" label selector' do
        get '/v3/apps?label_selector=foo=bar', nil, admin_header

        parsed_response = MultiJson.load(last_response.body)

        expected_pagination = {
            'total_results' => 1,
            'total_pages' => 1,
            'first' => { 'href' => "#{link_prefix}/v3/apps?label_selector=foo%3Dbar&page=1&per_page=50" },
            'last' => { 'href' => "#{link_prefix}/v3/apps?label_selector=foo%3Dbar&page=1&per_page=50" },
            'next' => nil,
            'previous' => nil
        }

        expect(last_response.status).to eq(200)
        expect(parsed_response['resources'].map { |r| r['guid'] }).to contain_exactly(app1.guid)
        expect(parsed_response['pagination']).to eq(expected_pagination)
      end

      it 'returns a 200 and the filtered apps for "==" label selector' do
        get '/v3/apps?label_selector=foo==bar', nil, admin_header

        parsed_response = MultiJson.load(last_response.body)

        expected_pagination = {
            'total_results' => 1,
            'total_pages' => 1,
            'first' => { 'href' => "#{link_prefix}/v3/apps?label_selector=foo%3D%3Dbar&page=1&per_page=50" },
            'last' => { 'href' => "#{link_prefix}/v3/apps?label_selector=foo%3D%3Dbar&page=1&per_page=50" },
            'next' => nil,
            'previous' => nil
        }

        expect(last_response.status).to eq(200)
        expect(parsed_response['resources'].map { |r| r['guid'] }).to contain_exactly(app1.guid)
        expect(parsed_response['pagination']).to eq(expected_pagination)
      end

      it 'returns a 200 and the filtered apps for "!=" label selector' do
        get '/v3/apps?label_selector=foo!=bar', nil, admin_header

        parsed_response = MultiJson.load(last_response.body)

        expected_pagination = {
      'total_results' => 1,
      'total_pages' => 1,
      'first' => { 'href' => "#{link_prefix}/v3/apps?label_selector=foo%21%3Dbar&page=1&per_page=50" },
      'last' => { 'href' => "#{link_prefix}/v3/apps?label_selector=foo%21%3Dbar&page=1&per_page=50" },
      'next' => nil,
      'previous' => nil
        }

        expect(last_response.status).to eq(200)
        expect(parsed_response['resources'].map { |r| r['guid'] }).to contain_exactly(app2.guid)
        expect(parsed_response['pagination']).to eq(expected_pagination)
      end

      it 'returns a 200 and the filtered apps for "==" label selector' do
        get '/v3/apps?label_selector=foo=funky,santa=claus', nil, admin_header

        parsed_response = MultiJson.load(last_response.body)

        expected_pagination = {
            'total_results' => 1,
            'total_pages' => 1,
            'first' => { 'href' => "#{link_prefix}/v3/apps?label_selector=foo%3Dfunky%2Csanta%3Dclaus&page=1&per_page=50" },
            'last' => { 'href' => "#{link_prefix}/v3/apps?label_selector=foo%3Dfunky%2Csanta%3Dclaus&page=1&per_page=50" },
            'next' => nil,
            'previous' => nil
        }

        expect(last_response.status).to eq(200)
        expect(parsed_response['resources'].map { |r| r['guid'] }).to contain_exactly(app2.guid)
        expect(parsed_response['pagination']).to eq(expected_pagination)
      end

      it 'returns a 200 and the filtered apps for existence label selector' do
        get '/v3/apps?label_selector=santa', nil, admin_header

        parsed_response = MultiJson.load(last_response.body)

        expected_pagination = {
            'total_results' => 1,
            'total_pages' => 1,
            'first' => { 'href' => "#{link_prefix}/v3/apps?label_selector=santa&page=1&per_page=50" },
            'last' => { 'href' => "#{link_prefix}/v3/apps?label_selector=santa&page=1&per_page=50" },
            'next' => nil,
            'previous' => nil
        }

        expect(last_response.status).to eq(200)
        expect(parsed_response['resources'].map { |r| r['guid'] }).to contain_exactly(app2.guid)
        expect(parsed_response['pagination']).to eq(expected_pagination)
      end

      it 'returns a 200 and the filtered apps for non-existence label selector' do
        get '/v3/apps?label_selector=!santa', nil, admin_header

        parsed_response = MultiJson.load(last_response.body)

        expected_pagination = {
            'total_results' => 1,
            'total_pages' => 1,
            'first' => { 'href' => "#{link_prefix}/v3/apps?label_selector=%21santa&page=1&per_page=50" },
            'last' => { 'href' => "#{link_prefix}/v3/apps?label_selector=%21santa&page=1&per_page=50" },
            'next' => nil,
            'previous' => nil
        }

        expect(last_response.status).to eq(200)
        expect(parsed_response['resources'].map { |r| r['guid'] }).to contain_exactly(app1.guid)
        expect(parsed_response['pagination']).to eq(expected_pagination)
      end
    end

    context 'labels and existing filters' do
      let!(:space1) { VCAP::CloudController::Space.make }
      let!(:space2) { VCAP::CloudController::Space.make }
      let!(:app1) { VCAP::CloudController::AppModel.make(name: 'name1', space: space1) }
      let!(:app2) { VCAP::CloudController::AppModel.make(name: 'name2', space: space2) }
      let!(:app3) { VCAP::CloudController::AppModel.make(name: 'name3', space: space2) }
      let!(:app1_label1) { VCAP::CloudController::AppLabelModel.make(resource_guid: app1.guid, key_name: 'foo', value: 'funky') }
      let!(:app2_label1) { VCAP::CloudController::AppLabelModel.make(resource_guid: app2.guid, key_name: 'foo', value: 'funky') }
      let!(:app2_label2) { VCAP::CloudController::AppLabelModel.make(resource_guid: app2.guid, key_name: 'fruit', value: 'strawberry') }
      let!(:app3_label1) { VCAP::CloudController::AppLabelModel.make(resource_guid: app3.guid, key_name: 'fruit', value: 'strawberry') }

      let(:admin_header) { headers_for(user, scopes: %w(cloud_controller.admin)) }

      it 'returns a 200 and the correct app when querying with space guid' do
        get "/v3/apps?space_guids=#{space2.guid}&label_selector=foo==funky", nil, admin_header

        parsed_response = MultiJson.load(last_response.body)

        expected_pagination = {
            'total_results' => 1,
            'total_pages' => 1,
            'first' => { 'href' => "#{link_prefix}/v3/apps?label_selector=foo%3D%3Dfunky&page=1&per_page=50&space_guids=#{space2.guid}" },
            'last' => { 'href' => "#{link_prefix}/v3/apps?label_selector=foo%3D%3Dfunky&page=1&per_page=50&space_guids=#{space2.guid}" },
            'next' => nil,
            'previous' => nil
        }

        expect(last_response.status).to eq(200)
        expect(parsed_response['resources'].map { |r| r['guid'] }).to contain_exactly(app2.guid)
        expect(parsed_response['pagination']).to eq(expected_pagination)
      end

      it 'returns a 200 and the correct app when querying with space guid' do
        get "/v3/apps?space_guids=#{space2.guid}&label_selector=fruit==strawberry&names=name2", nil, admin_header

        parsed_response = MultiJson.load(last_response.body)

        expected_pagination = {
            'total_results' => 1,
            'total_pages' => 1,
            'first' => { 'href' => "#{link_prefix}/v3/apps?label_selector=fruit%3D%3Dstrawberry&names=name2&page=1&per_page=50&space_guids=#{space2.guid}" },
            'last' => { 'href' => "#{link_prefix}/v3/apps?label_selector=fruit%3D%3Dstrawberry&names=name2&page=1&per_page=50&space_guids=#{space2.guid}" },
            'next' => nil,
            'previous' => nil
        }

        expect(last_response.status).to eq(200)
        expect(parsed_response['resources'].map { |r| r['guid'] }).to contain_exactly(app2.guid)
        expect(parsed_response['pagination']).to eq(expected_pagination)
      end
    end

    context 'including orgs and spaces' do
      it 'presents the apps listed with the orgs and spaces included' do
        VCAP::CloudController::AppModel.make(:docker, name: 'name1', guid: 'app1-guid', space: space)

        org1 = space.organization
        org2 = VCAP::CloudController::Organization.make(name: 'org2', guid: 'org2-guid', created_at: 1.day.ago)
        space2 = VCAP::CloudController::Space.make(name: 'space2', guid: 'space2-guid', organization: org2)

        unused_org = VCAP::CloudController::Organization.make(name: 'unused_org', guid: 'unused_org-guid')

        VCAP::CloudController::Space.make(name: 'unused_space', guid: 'unused_space-guid', organization: unused_org)

        VCAP::CloudController::AppModel.make(
          :docker,
          name: 'name2',
          guid: 'app2-guid',
          space: space2
        )

        get '/v3/apps?per_page=2&include=space,org', nil, admin_header
        expect(last_response.status).to eq(200)

        parsed_response = MultiJson.load(last_response.body)

        expect(parsed_response['included']['organizations'][0]).to be_a_response_like({
          'guid' => org1.guid,
          'created_at' => iso8601,
          'updated_at' => iso8601,
          'name' => org1.name,
          'status' => 'active',
          'metadata' => {
            'labels' => {},
            'annotations' => {},
          },
          'links' => {
            'self' => {
              'href' => "#{link_prefix}/v3/organizations/#{org1.guid}",
            },
            'default_domain' => {
              'href' => "#{link_prefix}/v3/organizations/#{org1.guid}/domains/default",
            },
            'domains' => {
              'href' => "#{link_prefix}/v3/organizations/#{org1.guid}/domains",
            },
          },
          'relationships' => { 'quota' => { 'data' => { 'guid' => org1.quota_definition.guid } } },
        })
        expect(parsed_response['included']['organizations'][1]).to be_a_response_like({
            'guid' => org2.guid,
            'created_at' => iso8601,
            'updated_at' => iso8601,
            'name' => org2.name,
          'status' => 'active',
            'metadata' => {
              'labels' => {},
              'annotations' => {},
            },
            'links' => {
              'self' => {
                'href' => "#{link_prefix}/v3/organizations/#{org2.guid}",
              },
              'default_domain' => {
                'href' => "#{link_prefix}/v3/organizations/#{org2.guid}/domains/default",
              },
              'domains' => {
                'href' => "#{link_prefix}/v3/organizations/#{org2.guid}/domains",
              },
            },
            'relationships' => { 'quota' => { 'data' => { 'guid' => org2.quota_definition.guid } } },
          })
      end

      it 'flags unsupported includes that contain supported ones' do
        get '/v3/apps?per_page=2&include=org,spaceship,borgs,space', nil, admin_header
        expect(last_response.status).to eq(400)
      end

      it 'does not include spaces if no one asks for them' do
        get '/v3/apps', nil, admin_header
        parsed_response = MultiJson.load(last_response.body)
        expect(parsed_response).to_not have_key('included')
      end
    end
  end

  describe 'GET /v3/apps/:guid' do
    let!(:buildpack) { VCAP::CloudController::Buildpack.make(name: 'bp-name') }
    let!(:stack) { VCAP::CloudController::Stack.make(name: 'stack-name') }
    let!(:app_model) { VCAP::CloudController::AppModel.make(
      :buildpack,
      name: 'my_app',
      space: space,
      desired_state: 'STARTED',
      environment_variables: { 'unicorn' => 'horn' },
      droplet_guid: 'a-droplet-guid'
    )
    }

    before do
      app_model.lifecycle_data.buildpacks = [buildpack.name]
      app_model.lifecycle_data.stack = stack.name
      app_model.lifecycle_data.save
      app_model.add_process(VCAP::CloudController::ProcessModel.make(instances: 1))
      app_model.add_process(VCAP::CloudController::ProcessModel.make(instances: 2))
    end

    it 'gets a specific app' do
      get "/v3/apps/#{app_model.guid}", nil, user_header
      expect(last_response.status).to eq(200)

      parsed_response = MultiJson.load(last_response.body)
      expect(parsed_response).to be_a_response_like(
        {
            'name' => 'my_app',
            'guid' => app_model.guid,
            'state' => 'STARTED',
            'created_at' => iso8601,
            'updated_at' => iso8601,
            'metadata' => { 'labels' => {}, 'annotations' => {} },
            'lifecycle' => {
                'type' => 'buildpack',
                'data' => {
                    'buildpacks' => ['bp-name'],
                    'stack' => 'stack-name',
                }
            },
            'relationships' => {
                'space' => {
                    'data' => {
                        'guid' => space.guid
                    }
                }
            },
            'links' => {
                'self' => { 'href' => "#{link_prefix}/v3/apps/#{app_model.guid}" },
                'processes' => { 'href' => "#{link_prefix}/v3/apps/#{app_model.guid}/processes" },
                'packages' => { 'href' => "#{link_prefix}/v3/apps/#{app_model.guid}/packages" },
                'environment_variables' => { 'href' => "#{link_prefix}/v3/apps/#{app_model.guid}/environment_variables" },
                'space' => { 'href' => "#{link_prefix}/v3/spaces/#{space.guid}" },
                'current_droplet' => { 'href' => "#{link_prefix}/v3/apps/#{app_model.guid}/droplets/current" },
                'droplets' => { 'href' => "#{link_prefix}/v3/apps/#{app_model.guid}/droplets" },
                'tasks' => { 'href' => "#{link_prefix}/v3/apps/#{app_model.guid}/tasks" },
                'route_mappings' => { 'href' => "#{link_prefix}/v3/apps/#{app_model.guid}/route_mappings" },
                'start' => { 'href' => "#{link_prefix}/v3/apps/#{app_model.guid}/actions/start", 'method' => 'POST' },
                'stop' => { 'href' => "#{link_prefix}/v3/apps/#{app_model.guid}/actions/stop", 'method' => 'POST' },
                'revisions' => { 'href' => "#{link_prefix}/v3/apps/#{app_model.guid}/revisions" },
                'deployed_revisions' => { 'href' => "#{link_prefix}/v3/apps/#{app_model.guid}/revisions/deployed" },
            }
        }
      )
    end

    it 'gets a specific app including space' do
      get "/v3/apps/#{app_model.guid}?include=space", nil, user_header
      expect(last_response.status).to eq(200)

      parsed_response = MultiJson.load(last_response.body)
      expect(parsed_response).to be_a_response_like(
        {
            'name' => 'my_app',
            'guid' => app_model.guid,
            'state' => 'STARTED',
            'created_at' => iso8601,
            'updated_at' => iso8601,
            'metadata' => { 'labels' => {}, 'annotations' => {} },
            'lifecycle' => {
                'type' => 'buildpack',
                'data' => {
                    'buildpacks' => ['bp-name'],
                    'stack' => 'stack-name',
                }
            },
            'relationships' => {
                'space' => {
                    'data' => {
                        'guid' => space.guid
                    }
                }
            },
            'links' => {
                'self' => { 'href' => "#{link_prefix}/v3/apps/#{app_model.guid}" },
                'processes' => { 'href' => "#{link_prefix}/v3/apps/#{app_model.guid}/processes" },
                'packages' => { 'href' => "#{link_prefix}/v3/apps/#{app_model.guid}/packages" },
                'environment_variables' => { 'href' => "#{link_prefix}/v3/apps/#{app_model.guid}/environment_variables" },
                'space' => { 'href' => "#{link_prefix}/v3/spaces/#{space.guid}" },
                'current_droplet' => { 'href' => "#{link_prefix}/v3/apps/#{app_model.guid}/droplets/current" },
                'droplets' => { 'href' => "#{link_prefix}/v3/apps/#{app_model.guid}/droplets" },
                'tasks' => { 'href' => "#{link_prefix}/v3/apps/#{app_model.guid}/tasks" },
                'route_mappings' => { 'href' => "#{link_prefix}/v3/apps/#{app_model.guid}/route_mappings" },
                'start' => { 'href' => "#{link_prefix}/v3/apps/#{app_model.guid}/actions/start", 'method' => 'POST' },
                'stop' => { 'href' => "#{link_prefix}/v3/apps/#{app_model.guid}/actions/stop", 'method' => 'POST' },
                'revisions' => { 'href' => "#{link_prefix}/v3/apps/#{app_model.guid}/revisions" },
                'deployed_revisions' => { 'href' => "#{link_prefix}/v3/apps/#{app_model.guid}/revisions/deployed" },
            },
            'included' => {
                'spaces' => [{
                                 'guid' => space.guid,
                                 'created_at' => iso8601,
                                 'updated_at' => iso8601,
                                 'name' => space.name,
                                 'relationships' => {
                                     'organization' => {
                                         'data' => {
                                             'guid' => space.organization.guid }
                                     }
                                 },
                                 'metadata' => {
                                     'labels' => {},
                                     'annotations' => {},
                                 },
                                 'links' => {
                                     'self' => {
                                         'href' => "#{link_prefix}/v3/spaces/#{space.guid}",
                                     },
                                     'organization' => {
                                         'href' => "#{link_prefix}/v3/organizations/#{space.organization.guid}"
                                     }
                                 }
                             }]
            }
        }
                                 )
    end

    it 'gets a specific app including space and org' do
      get "/v3/apps/#{app_model.guid}?include=org,space", nil, user_header
      expect(last_response.status).to eq(200)

      parsed_response = MultiJson.load(last_response.body)
      spaces = parsed_response['included']['spaces']
      orgs = parsed_response['included']['organizations']

      expect(spaces).to be_present
      expect(orgs[0]).to be_a_response_like(
        {
          'guid' => org.guid,
          'created_at' => iso8601,
          'updated_at' => iso8601,
          'name' => org.name,
          'status' => 'active',
          'metadata' => {
            'labels' => {},
            'annotations' => {},
          },
          'links' => {
            'self' => {
              'href' => "#{link_prefix}/v3/organizations/#{org.guid}",
            },
            'default_domain' => {
              'href' => "#{link_prefix}/v3/organizations/#{org.guid}/domains/default",
            },
            'domains' => {
              'href' => "#{link_prefix}/v3/organizations/#{org.guid}/domains",
            },
          },
          'relationships' => { 'quota' => { 'data' => { 'guid' => org.quota_definition.guid } } },
        }
      )
    end
  end

  describe 'GET /v3/apps/:guid/env' do
    it 'returns the environment of the app, including environment variables provided by the system' do
      app_model = VCAP::CloudController::AppModel.make(
        name: 'my_app',
        space: space,
        environment_variables: { 'unicorn' => 'horn' },
      )

      group = VCAP::CloudController::EnvironmentVariableGroup.staging
      group.environment_json = { STAGING_ENV: 'staging_value' }
      group.save

      group = VCAP::CloudController::EnvironmentVariableGroup.running
      group.environment_json = { RUNNING_ENV: 'running_value' }
      group.save

      service_instance = VCAP::CloudController::ManagedServiceInstance.make(
        space: space,
        name: 'si-name',
        tags: ['50% off']
      )
      VCAP::CloudController::ServiceBinding.make(
        service_instance: service_instance,
        app: app_model,
        syslog_drain_url: 'https://syslog.example.com/drain',
        credentials: { password: 'top-secret' }
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
                        'name' => 'si-name',
                        'instance_name' => 'si-name',
                        'binding_name' => nil,
                        'credentials' => { 'password' => 'top-secret' },
                        'syslog_drain_url' => 'https://syslog.example.com/drain',
                        'volume_mounts' => [],
                        'label' => service_instance.service.label,
                        'provider' => nil,
                        'plan' => service_instance.service_plan.name,
                        'tags' => ['50% off']
                    }
                  ]
              }
          },
          'application_env_json' => {
              'VCAP_APPLICATION' => {
                  'cf_api' => "#{TestConfig.config[:external_protocol]}://#{TestConfig.config[:external_domain]}",
                  'limits' => {
                      'fds' => 16384
                  },
                  'application_name' => 'my_app',
                  'application_uris' => [],
                  'name' => 'my_app',
                  'space_name' => space.name,
                  'space_id' => space.guid,
                  'organization_id' => space.organization.guid,
                'uris' => [],
                  'users' => nil,
                  'application_id' => app_model.guid
              }
          }
      }

      parsed_response = MultiJson.load(last_response.body)

      expect(last_response.status).to eq(200)
      expect(parsed_response).to be_a_response_like(expected_response)
    end
  end

  describe 'GET /v3/apps/:guid/builds' do
    let(:app_model) { VCAP::CloudController::AppModel.make(space: space, name: 'my-app') }
    let(:build) do
      VCAP::CloudController::BuildModel.make(
        package: package,
        app: app_model,
        created_by_user_name: 'bob the builder',
        created_by_user_guid: user.guid,
        created_by_user_email: 'bob@loblaw.com'
      )
    end
    let!(:second_build) do
      VCAP::CloudController::BuildModel.make(
        package: package,
        app: app_model,
        created_at: build.created_at - 1.day,
        created_by_user_name: 'bob the builder',
        created_by_user_guid: user.guid,
        created_by_user_email: 'bob@loblaw.com'
      )
    end
    let(:package) { VCAP::CloudController::PackageModel.make(app_guid: app_model.guid) }
    let(:droplet) { VCAP::CloudController::DropletModel.make(
      state: VCAP::CloudController::DropletModel::STAGED_STATE,
      package_guid: package.guid,
      build: build,
    )
    }
    let(:second_droplet) { VCAP::CloudController::DropletModel.make(
      state: VCAP::CloudController::DropletModel::STAGED_STATE,
      package_guid: package.guid,
      build: second_build,
    )
    }
    let(:body) do
      { lifecycle: { type: 'buildpack', data: { buildpacks: ['http://github.com/myorg/awesome-buildpack'],
                                                stack: 'cflinuxfs3' } } }
    end
    let(:staging_message) { VCAP::CloudController::BuildCreateMessage.new(body) }
    let(:per_page) { 2 }
    let(:order_by) { '-created_at' }

    before do
      VCAP::CloudController::BuildpackLifecycle.new(package, staging_message).create_lifecycle_data_model(build)
      VCAP::CloudController::BuildpackLifecycle.new(package, staging_message).create_lifecycle_data_model(second_build)
      build.update(state: droplet.state, error_description: droplet.error_description)
      second_build.update(state: second_droplet.state, error_description: second_droplet.error_description)
    end

    it 'lists the builds for app' do
      get "v3/apps/#{app_model.guid}/builds?order_by=#{order_by}&per_page=#{per_page}", nil, user_header

      parsed_response = MultiJson.load(last_response.body)

      expect(last_response.status).to eq(200)
      expect(parsed_response['resources']).to include(hash_including('guid' => build.guid))
      expect(parsed_response['resources']).to include(hash_including('guid' => second_build.guid))
      expect(parsed_response).to be_a_response_like({
                                                        'pagination' => {
                                                            'total_results' => 2,
                                                            'total_pages' => 1,
                                                            'first' => { 'href' => "#{link_prefix}/v3/apps/#{app_model.guid}/builds?order_by=#{order_by}&page=1&per_page=2" },
                                                            'last' => { 'href' => "#{link_prefix}/v3/apps/#{app_model.guid}/builds?order_by=#{order_by}&page=1&per_page=2" },
                                                            'next' => nil,
                                                            'previous' => nil,
                                                        },
                                                        'resources' => [
                                                          {
                                                              'guid' => build.guid,
                                                              'created_at' => iso8601,
                                                              'updated_at' => iso8601,
                                                              'state' => 'STAGED',
                                                              'error' => nil,
                                                              'lifecycle' => {
                                                                  'type' => 'buildpack',
                                                                  'data' => {
                                                                      'buildpacks' => ['http://github.com/myorg/awesome-buildpack'],
                                                                      'stack' => 'cflinuxfs3',
                                                                  },
                                                              },
                                                              'package' => { 'guid' => package.guid, },
                                                              'droplet' => {
                                                                  'guid' => droplet.guid,
                                                                  'href' => "#{link_prefix}/v3/droplets/#{droplet.guid}",
                                                              },
                                                              'metadata' => { 'labels' => {}, 'annotations' => {} },
                                                              'links' => {
                                                                  'self' => { 'href' => "#{link_prefix}/v3/builds/#{build.guid}", },
                                                                  'app' => { 'href' => "#{link_prefix}/v3/apps/#{package.app.guid}", }
                                                              },
                                                              'created_by' => { 'guid' => user.guid, 'name' => 'bob the builder', 'email' => 'bob@loblaw.com', }
                                                          },
                                                          {
                                                              'guid' => second_build.guid,
                                                              'created_at' => iso8601,
                                                              'updated_at' => iso8601,
                                                              'state' => 'STAGED',
                                                              'error' => nil,
                                                              'lifecycle' => {
                                                                  'type' => 'buildpack',
                                                                  'data' => {
                                                                      'buildpacks' => ['http://github.com/myorg/awesome-buildpack'],
                                                                      'stack' => 'cflinuxfs3',
                                                                  },
                                                              },
                                                              'package' => { 'guid' => package.guid, },
                                                              'droplet' => {
                                                                  'guid' => second_droplet.guid,
                                                                  'href' => "#{link_prefix}/v3/droplets/#{second_droplet.guid}",
                                                              },
                                                              'metadata' => { 'labels' => {}, 'annotations' => {} },
                                                              'links' => {
                                                                  'self' => { 'href' => "#{link_prefix}/v3/builds/#{second_build.guid}", },
                                                                  'app' => { 'href' => "#{link_prefix}/v3/apps/#{package.app.guid}", }
                                                              },
                                                              'created_by' => { 'guid' => user.guid, 'name' => 'bob the builder', 'email' => 'bob@loblaw.com', }
                                                          },
                                                        ]
                                                    })
    end

    it 'filters on label_selector' do
      VCAP::CloudController::BuildLabelModel.make(key_name: 'fruit', value: 'strawberry', build: build)

      get "/v3/apps/#{app_model.guid}/builds?label_selector=fruit=strawberry", {}, user_header

      expect(last_response.status).to eq(200)
      expect(parsed_response['resources'].count).to eq(1)
      expect(parsed_response['resources'][0]['guid']).to eq(build.guid)
    end
  end

  describe 'DELETE /v3/apps/guid' do
    let!(:app_model) { VCAP::CloudController::AppModel.make(name: 'app_name', space: space) }
    let!(:package) { VCAP::CloudController::PackageModel.make(app: app_model) }
    let!(:droplet) { VCAP::CloudController::DropletModel.make(package: package, app: app_model) }
    let!(:process) { VCAP::CloudController::ProcessModel.make(app: app_model) }
    let!(:deployment) { VCAP::CloudController::DeploymentModel.make(app: app_model) }
    let(:user_email) { nil }

    it 'deletes an App' do
      delete "/v3/apps/#{app_model.guid}", nil, user_header

      expect(last_response.status).to eq(202)
      expect(last_response.headers['Location']).to match(%r(/v3/jobs/#{VCAP::CloudController::PollableJobModel.last.guid}))

      Delayed::Worker.new.work_off

      expect(app_model.exists?).to be_falsey
      expect(package.exists?).to be_falsey
      expect(droplet.exists?).to be_falsey
      expect(process.exists?).to be_falsey
      expect(deployment.exists?).to be_falsey

      event = VCAP::CloudController::Event.last(2).first
      expect(event.values).to include({
                                          type: 'audit.app.delete-request',
                                          actee: app_model.guid,
                                          actee_type: 'app',
                                          actee_name: 'app_name',
                                          actor: user.guid,
                                          actor_type: 'user',
                                          actor_name: '',
                                          actor_username: user_name,
                                          space_guid: space.guid,
                                          organization_guid: space.organization.guid
                                      })
    end
  end

  describe 'PATCH /v3/apps/:guid' do
    it 'updates an app' do
      app_model = VCAP::CloudController::AppModel.make(
        :buildpack,
          name: 'original_name',
          space: space,
          environment_variables: { 'ORIGINAL' => 'ENVAR' },
          desired_state: 'STOPPED'
      )

      VCAP::CloudController::AppLabelModel.make(
        resource_guid: app_model.guid,
        key_name: 'delete-me',
        value: 'yes'
      )

      VCAP::CloudController::AppAnnotationModel.make(
        resource_guid: app_model.guid,
        key: 'anno1',
        value: 'original-value',
      )

      VCAP::CloudController::AppAnnotationModel.make(
        resource_guid: app_model.guid,
        key: 'please',
        value: 'delete this',
      )
      stack = VCAP::CloudController::Stack.make(name: 'redhat')

      update_request = {
          name: 'new-name',
          lifecycle: {
              type: 'buildpack',
              data: {
                  buildpacks: ['http://gitwheel.org/my-app'],
                  stack: stack.name
              }
          },
          metadata: {
              labels: {
                  'release' => 'stable',
                  'code.cloudfoundry.org/cloud_controller_ng' => 'awesome',
                  'delete-me' => nil,
              },
              annotations: {
                  'contacts' => 'Bill tel(1111111) email(bill@fixme), Bob tel(222222) pager(3333333#555) email(bob@fixme)',
                  'anno1' => 'new-value',
                  'please' => nil,
              }
          }

      }

      patch "/v3/apps/#{app_model.guid}", update_request.to_json, user_header
      expect(last_response.status).to eq(200)

      app_model.reload

      parsed_response = MultiJson.load(last_response.body)
      expect(parsed_response).to be_a_response_like(
        {
            'name' => 'new-name',
            'guid' => app_model.guid,
            'state' => 'STOPPED',
            'lifecycle' => {
                'type' => 'buildpack',
                'data' => {
                    'buildpacks' => ['http://gitwheel.org/my-app'],
                    'stack' => stack.name,
                }
            },
            'relationships' => {
                'space' => {
                    'data' => {
                        'guid' => space.guid
                    }
                }
            },
            'created_at' => iso8601,
            'updated_at' => iso8601,
            'metadata' => {
              'labels' => {
                  'release' => 'stable',
                  'code.cloudfoundry.org/cloud_controller_ng' => 'awesome'
                },
              'annotations' => {
                  'contacts' => 'Bill tel(1111111) email(bill@fixme), Bob tel(222222) pager(3333333#555) email(bob@fixme)',
                  'anno1' => 'new-value'
              }
            },
            'links' => {
                'self' => { 'href' => "#{link_prefix}/v3/apps/#{app_model.guid}" },
                'processes' => { 'href' => "#{link_prefix}/v3/apps/#{app_model.guid}/processes" },
                'packages' => { 'href' => "#{link_prefix}/v3/apps/#{app_model.guid}/packages" },
                'environment_variables' => { 'href' => "#{link_prefix}/v3/apps/#{app_model.guid}/environment_variables" },
                'space' => { 'href' => "#{link_prefix}/v3/spaces/#{space.guid}" },
                'current_droplet' => { 'href' => "#{link_prefix}/v3/apps/#{app_model.guid}/droplets/current" },
                'droplets' => { 'href' => "#{link_prefix}/v3/apps/#{app_model.guid}/droplets" },
                'tasks' => { 'href' => "#{link_prefix}/v3/apps/#{app_model.guid}/tasks" },
                'route_mappings' => { 'href' => "#{link_prefix}/v3/apps/#{app_model.guid}/route_mappings" },
                'start' => { 'href' => "#{link_prefix}/v3/apps/#{app_model.guid}/actions/start", 'method' => 'POST' },
                'stop' => { 'href' => "#{link_prefix}/v3/apps/#{app_model.guid}/actions/stop", 'method' => 'POST' },
                'revisions' => { 'href' => "#{link_prefix}/v3/apps/#{app_model.guid}/revisions" },
                'deployed_revisions' => { 'href' => "#{link_prefix}/v3/apps/#{app_model.guid}/revisions/deployed" },
            }
        }
                                 )

      event = VCAP::CloudController::Event.last
      expect(event.values).to include({
                                          type: 'audit.app.update',
                                          actee: app_model.guid,
                                          actee_type: 'app',
                                          actee_name: 'new-name',
                                          actor: user.guid,
                                          actor_type: 'user',
                                          actor_name: user_email,
                                          actor_username: user_name,
                                          space_guid: space.guid,
                                          organization_guid: space.organization.guid
                                      })
      metadata_request = {
        'name' => 'new-name',
        'lifecycle' => {
          'type' => 'buildpack',
          'data' => {
            'buildpacks' => ['http://gitwheel.org/my-app'],
            'stack' => stack.name
          }
        },
        'metadata' => {
          'labels' => {
            'release' => 'stable',
            'code.cloudfoundry.org/cloud_controller_ng' => 'awesome',
            'delete-me' => nil
          },
          'annotations' => {
            'contacts' => 'Bill tel(1111111) email(bill@fixme), Bob tel(222222) pager(3333333#555) email(bob@fixme)',
            'anno1' => 'new-value',
            'please' => nil,
          }
        }
      }
      expect(event.metadata['request']).to eq(metadata_request)
    end
  end

  describe 'PUT /v3/apps/:guid/start' do
    let(:stack) { VCAP::CloudController::Stack.make(name: 'stack-name') }
    let(:app_model) {
      VCAP::CloudController::AppModel.make(
        :buildpack,
        name: 'app-name',
        space: space,
        desired_state: 'STOPPED',
      )
    }
    it 'starts the app' do
      app_model.lifecycle_data.buildpacks = ['http://example.com/git']
      app_model.lifecycle_data.stack = stack.name
      app_model.lifecycle_data.save

      droplet = VCAP::CloudController::DropletModel.make(:buildpack, app: app_model, state: VCAP::CloudController::DropletModel::STAGED_STATE)
      app_model.droplet = droplet
      app_model.save

      post "/v3/apps/#{app_model.guid}/actions/start", nil, user_header
      expect(last_response.status).to eq(200)

      parsed_response = MultiJson.load(last_response.body)
      expect(parsed_response).to be_a_response_like({
                                                        'name' => 'app-name',
                                                        'guid' => app_model.guid,
                                                        'state' => 'STARTED',
                                                        'created_at' => iso8601,
                                                        'updated_at' => iso8601,
                                                        'metadata' => { 'labels' => {}, 'annotations' => {} },
                                                        'lifecycle' => {
                                                            'type' => 'buildpack',
                                                            'data' => {
                                                                'buildpacks' => ['http://example.com/git'],
                                                                'stack' => 'stack-name',
                                                            }
                                                        },
                                                        'relationships' => {
                                                            'space' => {
                                                                'data' => {
                                                                    'guid' => space.guid
                                                                }
                                                            }
                                                        },
                                                        'links' => {
                                                            'self' => { 'href' => "#{link_prefix}/v3/apps/#{app_model.guid}" },
                                                            'processes' => { 'href' => "#{link_prefix}/v3/apps/#{app_model.guid}/processes" },
                                                            'packages' => { 'href' => "#{link_prefix}/v3/apps/#{app_model.guid}/packages" },
                                                            'environment_variables' => { 'href' => "#{link_prefix}/v3/apps/#{app_model.guid}/environment_variables" },
                                                            'space' => { 'href' => "#{link_prefix}/v3/spaces/#{space.guid}" },
                                                            'current_droplet' => { 'href' => "#{link_prefix}/v3/apps/#{app_model.guid}/droplets/current" },
                                                            'droplets' => { 'href' => "#{link_prefix}/v3/apps/#{app_model.guid}/droplets" },
                                                            'tasks' => { 'href' => "#{link_prefix}/v3/apps/#{app_model.guid}/tasks" },
                                                            'route_mappings' => { 'href' => "#{link_prefix}/v3/apps/#{app_model.guid}/route_mappings" },
                                                            'start' => { 'href' => "#{link_prefix}/v3/apps/#{app_model.guid}/actions/start", 'method' => 'POST' },
                                                            'stop' => { 'href' => "#{link_prefix}/v3/apps/#{app_model.guid}/actions/stop", 'method' => 'POST' },
                                                            'revisions' => { 'href' => "#{link_prefix}/v3/apps/#{app_model.guid}/revisions" },
                                                            'deployed_revisions' => { 'href' => "#{link_prefix}/v3/apps/#{app_model.guid}/revisions/deployed" },
                                                        }
                                                    })

      event = VCAP::CloudController::Event.last
      expect(event.values).to include({
                                          type: 'audit.app.start',
                                          actee: app_model.guid,
                                          actee_type: 'app',
                                          actee_name: 'app-name',
                                          actor: user.guid,
                                          actor_type: 'user',
                                          actor_name: user_email,
                                          actor_username: user_name,
                                          space_guid: space.guid,
                                          organization_guid: space.organization.guid,
                                      })
    end

    describe 'when there is a new desired droplet and revision feature is turned on' do
      let(:droplet) {
        VCAP::CloudController::DropletModel.make(
          app: app_model,
          process_types: { web: 'rackup' },
          state: VCAP::CloudController::DropletModel::STAGED_STATE,
          package: VCAP::CloudController::PackageModel.make
        )
      }

      before do
        app_model.update(revisions_enabled: true)
      end

      it 'creates a new revision' do
        expect {
          patch "/v3/apps/#{app_model.guid}/relationships/current_droplet", { data: { guid: droplet.guid } }.to_json, user_header
          expect(last_response.status).to eq(200)
        }.to change { VCAP::CloudController::RevisionModel.count }.by(0)

        expect {
          post "/v3/apps/#{app_model.guid}/actions/start", nil, user_header
          expect(last_response.status).to eq(200), last_response.body
        }.to change { VCAP::CloudController::RevisionModel.count }.by(1)
      end
    end
  end

  describe 'POST /v3/apps/:guid/actions/stop' do
    it 'stops the app' do
      stack = VCAP::CloudController::Stack.make(name: 'stack-name')
      app_model = VCAP::CloudController::AppModel.make(
        :buildpack,
          name: 'app-name',
          space: space,
          desired_state: 'STARTED',
      )

      app_model.lifecycle_data.buildpacks = ['http://example.com/git']
      app_model.lifecycle_data.stack = stack.name
      app_model.lifecycle_data.save

      droplet = VCAP::CloudController::DropletModel.make(:buildpack, app: app_model, state: VCAP::CloudController::DropletModel::STAGED_STATE)
      app_model.droplet = droplet
      app_model.save

      post "/v3/apps/#{app_model.guid}/actions/stop", nil, user_header
      expect(last_response.status).to eq(200)

      parsed_response = MultiJson.load(last_response.body)
      expect(parsed_response).to be_a_response_like(
        {
            'name' => 'app-name',
            'guid' => app_model.guid,
            'state' => 'STOPPED',
            'created_at' => iso8601,
            'updated_at' => iso8601,
            'metadata' => { 'labels' => {}, 'annotations' => {} },
            'lifecycle' => {
                'type' => 'buildpack',
                'data' => {
                    'buildpacks' => ['http://example.com/git'],
                    'stack' => 'stack-name',
                }
            },
            'relationships' => {
                'space' => {
                    'data' => {
                        'guid' => space.guid
                    }
                }
            },
            'links' => {
                'self' => { 'href' => "#{link_prefix}/v3/apps/#{app_model.guid}" },
                'processes' => { 'href' => "#{link_prefix}/v3/apps/#{app_model.guid}/processes" },
                'packages' => { 'href' => "#{link_prefix}/v3/apps/#{app_model.guid}/packages" },
                'environment_variables' => { 'href' => "#{link_prefix}/v3/apps/#{app_model.guid}/environment_variables" },
                'space' => { 'href' => "#{link_prefix}/v3/spaces/#{space.guid}" },
                'current_droplet' => { 'href' => "#{link_prefix}/v3/apps/#{app_model.guid}/droplets/current" },
                'droplets' => { 'href' => "#{link_prefix}/v3/apps/#{app_model.guid}/droplets" },
                'tasks' => { 'href' => "#{link_prefix}/v3/apps/#{app_model.guid}/tasks" },
                'route_mappings' => { 'href' => "#{link_prefix}/v3/apps/#{app_model.guid}/route_mappings" },
                'start' => { 'href' => "#{link_prefix}/v3/apps/#{app_model.guid}/actions/start", 'method' => 'POST' },
                'stop' => { 'href' => "#{link_prefix}/v3/apps/#{app_model.guid}/actions/stop", 'method' => 'POST' },
                'revisions' => { 'href' => "#{link_prefix}/v3/apps/#{app_model.guid}/revisions" },
                'deployed_revisions' => { 'href' => "#{link_prefix}/v3/apps/#{app_model.guid}/revisions/deployed" },
            }
        }
                                 )

      event = VCAP::CloudController::Event.last
      expect(event.values).to include({
                                          type: 'audit.app.stop',
                                          actee: app_model.guid,
                                          actee_type: 'app',
                                          actee_name: 'app-name',
                                          actor: user.guid,
                                          actor_type: 'user',
                                          actor_name: user_email,
                                          actor_username: user_name,
                                          space_guid: space.guid,
                                          organization_guid: space.organization.guid,
                                      })
    end
  end

  describe 'POST /v3/apps/:guid/actions/restart' do
    it 'restart the app' do
      stack = VCAP::CloudController::Stack.make(name: 'stack-name')
      app_model = VCAP::CloudController::AppModel.make(
        :buildpack,
          name: 'app-name',
          space: space,
          desired_state: 'STARTED',
      )

      app_model.lifecycle_data.buildpacks = ['http://example.com/git']
      app_model.lifecycle_data.stack = stack.name
      app_model.lifecycle_data.save

      droplet = VCAP::CloudController::DropletModel.make(:buildpack, app: app_model, state: VCAP::CloudController::DropletModel::STAGED_STATE)
      app_model.droplet = droplet
      app_model.save

      post "/v3/apps/#{app_model.guid}/actions/restart", nil, user_header
      expect(last_response.status).to eq(200)

      parsed_response = MultiJson.load(last_response.body)
      expect(parsed_response).to be_a_response_like(
        {
            'name' => 'app-name',
            'guid' => app_model.guid,
            'state' => 'STARTED',
            'created_at' => iso8601,
            'updated_at' => iso8601,
            'metadata' => { 'labels' => {}, 'annotations' => {} },
            'lifecycle' => {
                'type' => 'buildpack',
                'data' => {
                    'buildpacks' => ['http://example.com/git'],
                    'stack' => 'stack-name',
                }
            },
            'relationships' => {
                'space' => {
                    'data' => {
                        'guid' => space.guid
                    }
                }
            },
            'links' => {
                'self' => { 'href' => "#{link_prefix}/v3/apps/#{app_model.guid}" },
                'processes' => { 'href' => "#{link_prefix}/v3/apps/#{app_model.guid}/processes" },
                'packages' => { 'href' => "#{link_prefix}/v3/apps/#{app_model.guid}/packages" },
                'environment_variables' => { 'href' => "#{link_prefix}/v3/apps/#{app_model.guid}/environment_variables" },
                'space' => { 'href' => "#{link_prefix}/v3/spaces/#{space.guid}" },
                'current_droplet' => { 'href' => "#{link_prefix}/v3/apps/#{app_model.guid}/droplets/current" },
                'droplets' => { 'href' => "#{link_prefix}/v3/apps/#{app_model.guid}/droplets" },
                'tasks' => { 'href' => "#{link_prefix}/v3/apps/#{app_model.guid}/tasks" },
                'route_mappings' => { 'href' => "#{link_prefix}/v3/apps/#{app_model.guid}/route_mappings" },
                'start' => { 'href' => "#{link_prefix}/v3/apps/#{app_model.guid}/actions/start", 'method' => 'POST' },
                'stop' => { 'href' => "#{link_prefix}/v3/apps/#{app_model.guid}/actions/stop", 'method' => 'POST' },
                'revisions' => { 'href' => "#{link_prefix}/v3/apps/#{app_model.guid}/revisions" },
                'deployed_revisions' => { 'href' => "#{link_prefix}/v3/apps/#{app_model.guid}/revisions/deployed" },
            }
        }
                                 )
    end
  end

  describe 'GET /v3/apps/:guid/relationships/current_droplet' do
    let(:app_model) { VCAP::CloudController::AppModel.make(space_guid: space.guid) }
    let(:guid) { droplet_model.guid }
    let(:package_model) { VCAP::CloudController::PackageModel.make(app_guid: app_model.guid) }
    let!(:droplet_model) do
      VCAP::CloudController::DropletModel.make(
        state: VCAP::CloudController::DropletModel::STAGED_STATE,
        app_guid: app_model.guid,
        package_guid: package_model.guid,
        buildpack_receipt_buildpack: 'http://buildpack.git.url.com',
        error_description: 'example error',
        execution_metadata: 'some-data',
        droplet_hash: 'shalalala',
        sha256_checksum: 'droplet-sha256-checksum',
        process_types: { 'web' => 'start-command' },
      )
    end
    let(:app_guid) { droplet_model.app_guid }

    before do
      droplet_model.buildpack_lifecycle_data.update(buildpacks: ['http://buildpack.git.url.com'], stack: 'stack-name')
      app_model.droplet_guid = droplet_model.guid
      app_model.save
    end

    it 'gets the current droplet relationship' do
      get "/v3/apps/#{app_model.guid}/relationships/current_droplet", nil, user_header

      parsed_response = MultiJson.load(last_response.body)

      expect(last_response.status).to eq(200)
      expect(parsed_response).to be_a_response_like({
                                                        'data' => {
                                                            'guid' => droplet_model.guid
                                                        },
                                                        'links' => {
                                                            'self' => { 'href' => "#{link_prefix}/v3/apps/#{app_guid}/relationships/current_droplet" },
                                                            'related' => { 'href' => "#{link_prefix}/v3/apps/#{app_guid}/droplets/current" }
                                                        }
                                                    })
    end
  end

  describe 'GET /v3/apps/:guid/droplets/current' do
    let(:app_model) { VCAP::CloudController::AppModel.make(space_guid: space.guid) }
    let(:guid) { droplet_model.guid }
    let(:package_model) { VCAP::CloudController::PackageModel.make(app_guid: app_model.guid) }
    let!(:droplet_model) do
      VCAP::CloudController::DropletModel.make(
        state: VCAP::CloudController::DropletModel::STAGED_STATE,
        app_guid: app_model.guid,
        package_guid: package_model.guid,
        buildpack_receipt_buildpack: 'http://buildpack.git.url.com',
        error_description: 'example error',
        execution_metadata: 'some-data',
        droplet_hash: 'shalalala',
        sha256_checksum: 'droplet-sha256-checksum',
        process_types: { 'web' => 'start-command' },
      )
    end
    let(:app_guid) { droplet_model.app_guid }

    before do
      droplet_model.buildpack_lifecycle_data.update(buildpacks: ['http://buildpack.git.url.com'], stack: 'stack-name')
      app_model.droplet_guid = droplet_model.guid
      app_model.save
    end

    it 'gets the current droplet' do
      get "/v3/apps/#{app_model.guid}/droplets/current", nil, user_header

      parsed_response = MultiJson.load(last_response.body)

      expect(last_response.status).to eq(200)
      expect(parsed_response).to be_a_response_like({
        'guid' => droplet_model.guid,
        'state' => VCAP::CloudController::DropletModel::STAGED_STATE,
        'error' => 'example error',
        'lifecycle' => {
            'type' => 'buildpack',
            'data' => {}
        },
        'checksum' => { 'type' => 'sha256', 'value' => 'droplet-sha256-checksum' },
        'buildpacks' => [{ 'name' => 'http://buildpack.git.url.com', 'detect_output' => nil, 'buildpack_name' => nil,
                           'version' => nil }],
        'stack' => 'stack-name',
        'execution_metadata' => 'some-data',
        'process_types' => { 'web' => 'start-command' },
        'image' => nil,
        'created_at' => iso8601,
        'updated_at' => iso8601,
        'links' => {
            'self' => { 'href' => "#{link_prefix}/v3/droplets/#{guid}" },
            'package' => { 'href' => "#{link_prefix}/v3/packages/#{package_model.guid}" },
            'app' => { 'href' => "#{link_prefix}/v3/apps/#{app_guid}" },
            'assign_current_droplet' => { 'href' => "#{link_prefix}/v3/apps/#{app_guid}/relationships/current_droplet",
                                          'method' => 'PATCH' },
        },
        'metadata' => {
          'labels' => {},
          'annotations' => {}
        },
      })
    end
  end

  describe 'PATCH /v3/apps/:guid/relationships/current_droplet' do
    let(:stack) { VCAP::CloudController::Stack.make(name: 'stack-name') }
    let(:app_model) do
      VCAP::CloudController::AppModel.make(
        :buildpack,
          name: 'my_app',
          space: space,
          desired_state: 'STOPPED',
      )
    end

    before do
      app_model.lifecycle_data.buildpacks = ['http://example.com/git']
      app_model.lifecycle_data.stack = stack.name
      app_model.lifecycle_data.save
    end

    it 'assigns the current droplet of the app' do
      droplet = VCAP::CloudController::DropletModel.make(:docker,
                                                         app: app_model,
                                                         process_types: { web: 'rackup' },
                                                         state: VCAP::CloudController::DropletModel::STAGED_STATE,
                                                         package: VCAP::CloudController::PackageModel.make
      )

      request_body = { data: { guid: droplet.guid } }

      patch "/v3/apps/#{app_model.guid}/relationships/current_droplet", request_body.to_json, user_header

      expected_response = {
          'data' => {
              'guid' => droplet.guid
          },
          'links' => {
              'self' => { 'href' => "#{link_prefix}/v3/apps/#{app_model.guid}/relationships/current_droplet" },
              'related' => { 'href' => "#{link_prefix}/v3/apps/#{app_model.guid}/droplets/current" }
          }
      }

      parsed_response = MultiJson.load(last_response.body)

      expect(last_response.status).to eq(200)
      expect(parsed_response).to be_a_response_like(expected_response)

      events = VCAP::CloudController::Event.where(actor: user.guid).all

      droplet_event = events.find { |e| e.type == 'audit.app.droplet.mapped' }
      expect(droplet_event.values).to include({
                                                  type: 'audit.app.droplet.mapped',
                                                  actee: app_model.guid,
                                                  actee_type: 'app',
                                                  actee_name: 'my_app',
                                                  actor: user.guid,
                                                  actor_type: 'user',
                                                  actor_name: user_email,
                                                  actor_username: user_name,
                                                  space_guid: space.guid,
                                                  organization_guid: space.organization.guid
                                              })
      expect(droplet_event.metadata).to eq({ 'request' => { 'droplet_guid' => droplet.guid } })

      expect(app_model.reload.processes.count).to eq(1)
    end

    it 'creates audit.app.process.create events' do
      droplet = VCAP::CloudController::DropletModel.make(
        app: app_model,
        process_types: { web: 'rackup', other: 'cron' },
        state: VCAP::CloudController::DropletModel::STAGED_STATE
      )

      request_body = { data: { guid: droplet.guid } }

      patch "/v3/apps/#{app_model.guid}/relationships/current_droplet", request_body.to_json, user_header

      expect(last_response.status).to eq(200)

      events = VCAP::CloudController::Event.where(actor: user.guid).all

      expect(app_model.reload.processes.count).to eq(2)
      web_process = app_model.processes.find { |i| i.type == 'web' }
      other_process = app_model.processes.find { |i| i.type == 'other' }
      expect(web_process).to be_present
      expect(other_process).to be_present

      web_process_event = events.find { |e| e.metadata['process_guid'] == web_process.guid }
      expect(web_process_event.values).to include({
                                                      type: 'audit.app.process.create',
                                                      actee: app_model.guid,
                                                      actee_type: 'app',
                                                      actee_name: 'my_app',
                                                      actor: user.guid,
                                                      actor_type: 'user',
                                                      actor_name: user_email,
                                                      actor_username: user_name,
                                                      space_guid: space.guid,
                                                      organization_guid: space.organization.guid
                                                  })
      expect(web_process_event.metadata).to eq({ 'process_guid' => web_process.guid, 'process_type' => 'web' })

      other_process_event = events.find { |e| e.metadata['process_guid'] == other_process.guid }
      expect(other_process_event.values).to include({
                                                        type: 'audit.app.process.create',
                                                        actee: app_model.guid,
                                                        actee_type: 'app',
                                                        actee_name: 'my_app',
                                                        actor: user.guid,
                                                        actor_type: 'user',
                                                        actor_name: user_email,
                                                        actor_username: user_name,
                                                        space_guid: space.guid,
                                                        organization_guid: space.organization.guid
                                                    })
      expect(other_process_event.metadata).to eq({ 'process_guid' => other_process.guid, 'process_type' => 'other' })
    end
  end

  describe 'PATCH /v3/apps/:guid/environment_variables' do
    it 'patches the environment variables for the app' do
      app_model = VCAP::CloudController::AppModel.make(
        name: 'name1',
        space: space,
        desired_state: 'STOPPED',
        environment_variables: {
            override: 'original',
            preserve: 'keep'
        }
      )

      update_request = {
          var: {
              override: 'new-value',
              new_key: 'brand-new-value'
          }
      }

      patch "/v3/apps/#{app_model.guid}/environment_variables", update_request.to_json, user_header
      expect(last_response.status).to eq(200)

      parsed_response = MultiJson.load(last_response.body)
      expect(parsed_response).to be_a_response_like(
        {
            'var' => {
                'override' => 'new-value',
                'new_key' => 'brand-new-value',
                'preserve' => 'keep'
            },
            'links' => {
                'self' => { 'href' => "#{link_prefix}/v3/apps/#{app_model.guid}/environment_variables" },
                'app' => { 'href' => "#{link_prefix}/v3/apps/#{app_model.guid}" },
            }
        }
                                 )
    end
  end

  describe 'GET /v3/apps/:guid/environment_variables' do
    it 'gets the environment variables for the app' do
      app_model = VCAP::CloudController::AppModel.make(name: 'name1', space: space, desired_state: 'STOPPED', environment_variables: { meep: 'moop' })

      get "/v3/apps/#{app_model.guid}/environment_variables", nil, user_header
      expect(last_response.status).to eq(200)

      parsed_response = MultiJson.load(last_response.body)
      expect(parsed_response).to be_a_response_like(
        {
            'var' => {
                'meep' => 'moop'
            },
            'links' => {
                'self' => { 'href' => "#{link_prefix}/v3/apps/#{app_model.guid}/environment_variables" },
                'app' => { 'href' => "#{link_prefix}/v3/apps/#{app_model.guid}" },
            }
        }
                                 )
    end
  end
end
