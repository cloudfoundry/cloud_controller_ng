require 'spec_helper'
require 'actions/process_create_from_app_droplet'
require 'request_spec_shared_examples'
require_relative 'shared_context'

# Split from spec/request/apps_spec.rb for better test parallelization

RSpec.describe 'Apps' do
  include_context 'apps request spec'

  describe 'GET /v3/apps' do
    before do
      space.organization.add_user(user)
    end

    context 'listing all apps' do
      let(:api_call) { ->(user_headers) { get '/v3/apps', nil, user_headers } }
      let(:space2) { VCAP::CloudController::Space.make(organization: org) }
      let(:buildpack_lifecycle) { VCAP::CloudController::BuildpackLifecycleDataModel.make(stack: 'cool-stack', app: app_model1) }
      let(:app_model1) { VCAP::CloudController::AppModel.make(guid: 'app1_guid', name: 'name1', space: space) }
      let(:app_model2) { VCAP::CloudController::AppModel.make(guid: 'app2_guid', name: 'name2', space: space2) }

      let(:app_model1_response_object) do
        {
          guid: app_model1.guid,
          created_at: iso8601,
          updated_at: iso8601,
          name: app_model1.name,
          state: 'STOPPED',
          lifecycle: {
            type: 'buildpack',
            data: { buildpacks: [], stack: app_model1.lifecycle_data.stack }
          },
          relationships: {
            space: { data: { guid: space.guid } },
            current_droplet: { data: { guid: nil } }
          },
          metadata: {
            labels: {},
            annotations: {}
          },
          links: {
            self: { href: "#{link_prefix}/v3/apps/app1_guid" },
            environment_variables: { href: "#{link_prefix}/v3/apps/app1_guid/environment_variables" },
            space: { href: "#{link_prefix}/v3/spaces/#{space.guid}" },
            processes: { href: "#{link_prefix}/v3/apps/app1_guid/processes" },
            packages: { href: "#{link_prefix}/v3/apps/app1_guid/packages" },
            current_droplet: { href: "#{link_prefix}/v3/apps/app1_guid/droplets/current" },
            droplets: { href: "#{link_prefix}/v3/apps/app1_guid/droplets" },
            tasks: { href: "#{link_prefix}/v3/apps/app1_guid/tasks" },
            start: { href: "#{link_prefix}/v3/apps/app1_guid/actions/start", method: 'POST' },
            stop: { href: "#{link_prefix}/v3/apps/app1_guid/actions/stop", method: 'POST' },
            clear_buildpack_cache: { href: "#{link_prefix}/v3/apps/app1_guid/actions/clear_buildpack_cache", method: 'POST' },
            revisions: { href: "#{link_prefix}/v3/apps/app1_guid/revisions" },
            deployed_revisions: { href: "#{link_prefix}/v3/apps/app1_guid/revisions/deployed" },
            features: { href: "#{link_prefix}/v3/apps/app1_guid/features" }
          }
        }
      end

      let(:app_model2_response_object) do
        {
          guid: app_model2.guid,
          created_at: iso8601,
          updated_at: iso8601,
          name: app_model2.name,
          state: 'STOPPED',
          lifecycle: {
            type: 'buildpack',
            data: { buildpacks: [], stack: app_model2.lifecycle_data.stack }
          },
          relationships: {
            space: { data: { guid: space2.guid } },
            current_droplet: { data: { guid: nil } }
          },
          metadata: {
            labels: {},
            annotations: {}
          },
          links: {
            self: { href: "#{link_prefix}/v3/apps/app2_guid" },
            environment_variables: { href: "#{link_prefix}/v3/apps/app2_guid/environment_variables" },
            space: { href: "#{link_prefix}/v3/spaces/#{space2.guid}" },
            processes: { href: "#{link_prefix}/v3/apps/app2_guid/processes" },
            packages: { href: "#{link_prefix}/v3/apps/app2_guid/packages" },
            current_droplet: { href: "#{link_prefix}/v3/apps/app2_guid/droplets/current" },
            droplets: { href: "#{link_prefix}/v3/apps/app2_guid/droplets" },
            tasks: { href: "#{link_prefix}/v3/apps/app2_guid/tasks" },
            start: { href: "#{link_prefix}/v3/apps/app2_guid/actions/start", method: 'POST' },
            stop: { href: "#{link_prefix}/v3/apps/app2_guid/actions/stop", method: 'POST' },
            clear_buildpack_cache: { href: "#{link_prefix}/v3/apps/app2_guid/actions/clear_buildpack_cache", method: 'POST' },
            revisions: { href: "#{link_prefix}/v3/apps/app2_guid/revisions" },
            deployed_revisions: { href: "#{link_prefix}/v3/apps/app2_guid/revisions/deployed" },
            features: { href: "#{link_prefix}/v3/apps/app2_guid/features" }
          }
        }
      end

      let(:expected_codes_and_responses) do
        h = Hash.new({ code: 200, response_objects: [app_model1_response_object, app_model2_response_object] }.freeze)

        h['org_auditor'] = {
          code: 200,
          response_objects: []
        }

        h['org_billing_manager'] = {
          code: 200,
          response_objects: []
        }

        h['space_manager'] = {
          code: 200,
          response_objects: [
            app_model1_response_object
          ]
        }

        h['space_auditor'] = {
          code: 200,
          response_objects: [
            app_model1_response_object
          ]
        }

        h['space_developer'] = {
          code: 200,
          response_objects: [
            app_model1_response_object
          ]
        }

        h['space_supporter'] = {
          code: 200,
          response_objects: [
            app_model1_response_object
          ]
        }

        h['no_role'] = { code: 200, response_objects: [] }
        h
      end

      it_behaves_like 'permissions for list endpoint', ALL_PERMISSIONS
    end

    describe 'query list parameters' do
      it_behaves_like 'list query endpoint' do
        let(:request) { 'v3/apps' }

        let(:message) { VCAP::CloudController::AppsListMessage }

        let(:params) do
          {
            page: '2',
            per_page: '10',
            order_by: 'updated_at',
            names: 'foo',
            guids: 'foo',
            organization_guids: 'foo',
            space_guids: 'foo',
            stacks: 'cf',
            include: 'space',
            lifecycle_type: 'buildpack',
            label_selector: 'foo,bar',
            created_ats: "#{Time.now.utc.iso8601},#{Time.now.utc.iso8601}",
            updated_ats: { gt: Time.now.utc.iso8601 }
          }
        end

        let!(:app_model) { VCAP::CloudController::AppModel.make }
      end
    end

    context 'pagination' do
      before do
        space.add_developer(user)
      end

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
        VCAP::CloudController::AppModel.make(space:)
        VCAP::CloudController::AppModel.make

        get '/v3/apps?per_page=2&include=space', nil, user_header
        expect(last_response.status).to eq(200)

        parsed_response = Oj.load(last_response.body)
        expect(parsed_response).to be_a_response_like(
          {
            'pagination' => {
              'total_results' => 3,
              'total_pages' => 2,
              'first' => { 'href' => "#{link_prefix}/v3/apps?include=space&page=1&per_page=2" },
              'last' => { 'href' => "#{link_prefix}/v3/apps?include=space&page=2&per_page=2" },
              'next' => { 'href' => "#{link_prefix}/v3/apps?include=space&page=2&per_page=2" },
              'previous' => nil
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
                    'stack' => 'stack-name'
                  }
                },
                'relationships' => {
                  'space' => {
                    'data' => {
                      'guid' => space.guid
                    }
                  },
                  'current_droplet' => {
                    'data' => {
                      'guid' => nil
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
                  'start' => { 'href' => "#{link_prefix}/v3/apps/#{app_model1.guid}/actions/start", 'method' => 'POST' },
                  'stop' => { 'href' => "#{link_prefix}/v3/apps/#{app_model1.guid}/actions/stop", 'method' => 'POST' },
                  'clear_buildpack_cache' => { 'href' => "#{link_prefix}/v3/apps/#{app_model1.guid}/actions/clear_buildpack_cache", 'method' => 'POST' },
                  'revisions' => { 'href' => "#{link_prefix}/v3/apps/#{app_model1.guid}/revisions" },
                  'deployed_revisions' => { 'href' => "#{link_prefix}/v3/apps/#{app_model1.guid}/revisions/deployed" },
                  'features' => { 'href' => "#{link_prefix}/v3/apps/#{app_model1.guid}/features" }
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
                  },
                  'current_droplet' => {
                    'data' => {
                      'guid' => nil
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
                  'start' => { 'href' => "#{link_prefix}/v3/apps/#{app_model2.guid}/actions/start", 'method' => 'POST' },
                  'stop' => { 'href' => "#{link_prefix}/v3/apps/#{app_model2.guid}/actions/stop", 'method' => 'POST' },
                  'clear_buildpack_cache' => { 'href' => "#{link_prefix}/v3/apps/#{app_model2.guid}/actions/clear_buildpack_cache", 'method' => 'POST' },
                  'revisions' => { 'href' => "#{link_prefix}/v3/apps/#{app_model2.guid}/revisions" },
                  'deployed_revisions' => { 'href' => "#{link_prefix}/v3/apps/#{app_model2.guid}/revisions/deployed" },
                  'features' => { 'href' => "#{link_prefix}/v3/apps/#{app_model2.guid}/features" }
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
                      'guid' => space.organization.guid
                    }
                  },
                  'quota' => {
                    'data' => nil
                  }
                },
                'metadata' => {
                  'labels' => {},
                  'annotations' => {}
                },
                'links' => {
                  'self' => {
                    'href' => "#{link_prefix}/v3/spaces/#{space.guid}"
                  },
                  'organization' => {
                    'href' => "#{link_prefix}/v3/organizations/#{space.organization.guid}"
                  },
                  'features' => { 'href' => %r{#{Regexp.escape(link_prefix)}/v3/spaces/#{space.guid}/features} },
                  'apply_manifest' => {
                    'href' => "#{link_prefix}/v3/spaces/#{space.guid}/actions/apply_manifest",
                    'method' => 'POST'
                  }
                }
              }]
            }
          }
        )
      end
    end

    context 'filtering by timestamps' do
      before do
        VCAP::CloudController::AppModel.plugin :timestamps, update_on_create: false
      end

      # .make updates the resource after creating it, over writing our passed in updated_at timestamp
      # Therefore we cannot use shared_examples as the updated_at will not be as written
      let!(:resource_1) { VCAP::CloudController::AppModel.create(name: '1', created_at: '2020-05-26T18:47:01Z', updated_at: '2020-05-26T18:47:01Z', space: space) }
      let!(:resource_2) { VCAP::CloudController::AppModel.create(name: '2', created_at: '2020-05-26T18:47:02Z', updated_at: '2020-05-26T18:47:02Z', space: space) }
      let!(:resource_3) { VCAP::CloudController::AppModel.create(name: '3', created_at: '2020-05-26T18:47:03Z', updated_at: '2020-05-26T18:47:03Z', space: space) }
      let!(:resource_4) { VCAP::CloudController::AppModel.create(name: '4', created_at: '2020-05-26T18:47:04Z', updated_at: '2020-05-26T18:47:04Z', space: space) }

      after do
        VCAP::CloudController::AppModel.plugin :timestamps, update_on_create: true
      end

      it 'filters by the created at' do
        get "/v3/apps?created_ats[lt]=#{resource_3.created_at.iso8601}", nil, admin_header

        expect(last_response).to have_status_code(200)
        expect(parsed_response['resources'].pluck('guid')).to contain_exactly(resource_1.guid, resource_2.guid)
      end

      it 'filters ny the updated_at' do
        get "/v3/apps?updated_ats[lt]=#{resource_3.updated_at.iso8601}", nil, admin_header

        expect(last_response).to have_status_code(200)
        expect(parsed_response['resources'].pluck('guid')).to contain_exactly(resource_1.guid, resource_2.guid)
      end
    end

    context 'faceted search' do
      let(:admin_header) { headers_for(user, scopes: %w[cloud_controller.admin]) }

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

        parsed_response = Oj.load(last_response.body)

        expect(last_response.status).to eq(200)
        expect(parsed_response['resources'].pluck('name')).to eq(%w[name1 name3])
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

        parsed_response = Oj.load(last_response.body)

        expect(last_response.status).to eq(200)
        expect(parsed_response['resources'].pluck('name')).to eq(%w[name1 name2])
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

        parsed_response = Oj.load(last_response.body)

        expect(last_response.status).to eq(200)
        expect(parsed_response['resources'].pluck('name')).to eq(%w[name1 name3])
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

        parsed_response = Oj.load(last_response.body)

        expect(last_response.status).to eq(200)
        expect(parsed_response['resources'].pluck('name')).to eq(%w[name1 name3])
        expect(parsed_response['pagination']).to eq(expected_pagination)
      end

      it 'filters by stack names' do
        app_model1 = VCAP::CloudController::AppModel.make(name: 'name1')
        app_model2 = VCAP::CloudController::AppModel.make(name: 'name2')
        app_model3 = VCAP::CloudController::AppModel.make(name: 'name3')

        stack2 = VCAP::CloudController::Stack.make(name: 'name2')
        stack3 = VCAP::CloudController::Stack.make(name: 'name3')

        app_model1.lifecycle_data.stack = stack2.name
        app_model1.lifecycle_data.save

        app_model2.lifecycle_data.stack = stack2.name
        app_model2.lifecycle_data.save

        app_model3.lifecycle_data.stack = stack3.name
        app_model3.lifecycle_data.save

        get "/v3/apps?stacks=#{stack2.name}", nil, admin_header

        expected_pagination = {
          'total_results' => 2,
          'total_pages' => 1,
          'first' => { 'href' => "#{link_prefix}/v3/apps?page=1&per_page=50&stacks=#{stack2.name}" },
          'last' => { 'href' => "#{link_prefix}/v3/apps?page=1&per_page=50&stacks=#{stack2.name}" },
          'next' => nil,
          'previous' => nil
        }

        parsed_response = Oj.load(last_response.body)

        expect(last_response.status).to eq(200)
        expect(parsed_response['resources'].pluck('name')).to eq(%w[name1 name2])
        expect(parsed_response['pagination']).to eq(expected_pagination)
      end

      it 'filters by null stacks' do
        app_model1 = VCAP::CloudController::AppModel.make(name: 'name1')
        app_model2 = VCAP::CloudController::AppModel.make(name: 'name2')
        app_model3 = VCAP::CloudController::AppModel.make(name: 'name3')

        stack2 = VCAP::CloudController::Stack.make(name: 'name2')
        stack3 = VCAP::CloudController::Stack.make(name: 'name3')

        app_model1.lifecycle_data.stack = nil
        app_model1.lifecycle_data.save

        app_model2.lifecycle_data.stack = stack2.name
        app_model2.lifecycle_data.save

        app_model3.lifecycle_data.stack = stack3.name
        app_model3.lifecycle_data.save

        get '/v3/apps?stacks=', nil, admin_header

        expected_pagination = {
          'total_results' => 1,
          'total_pages' => 1,
          'first' => { 'href' => "#{link_prefix}/v3/apps?page=1&per_page=50&stacks=" },
          'last' => { 'href' => "#{link_prefix}/v3/apps?page=1&per_page=50&stacks=" },
          'next' => nil,
          'previous' => nil
        }

        parsed_response = Oj.load(last_response.body)

        expect(last_response.status).to eq(200)
        expect(parsed_response['resources'].pluck('name')).to eq(['name1'])
        expect(parsed_response['pagination']).to eq(expected_pagination)
      end

      it 'filters by lifecycle_type' do
        VCAP::CloudController::AppModel.make(name: 'name1')
        docker_app_model = VCAP::CloudController::AppModel.make(name: 'name2')
        VCAP::CloudController::AppModel.make(name: 'name3')

        docker_app_model.buildpack_lifecycle_data = nil
        docker_app_model.save

        get '/v3/apps?lifecycle_type=buildpack', nil, admin_header

        expected_pagination = {
          'total_results' => 2,
          'total_pages' => 1,
          'first' => { 'href' => "#{link_prefix}/v3/apps?lifecycle_type=buildpack&page=1&per_page=50" },
          'last' => { 'href' => "#{link_prefix}/v3/apps?lifecycle_type=buildpack&page=1&per_page=50" },
          'next' => nil,
          'previous' => nil
        }

        parsed_response = Oj.load(last_response.body)

        expect(last_response.status).to eq(200)
        expect(parsed_response['resources'].pluck('name')).to eq(%w[name1 name3])
        expect(parsed_response['pagination']).to eq(expected_pagination)
      end
    end

    context 'ordering' do
      before do
        space.add_developer(user)
      end

      it 'can order by name' do
        VCAP::CloudController::AppModel.make(space: space, name: 'zed')
        VCAP::CloudController::AppModel.make(space: space, name: 'alpha')
        VCAP::CloudController::AppModel.make(space: space, name: 'gamma')
        VCAP::CloudController::AppModel.make(space: space, name: 'delta')
        VCAP::CloudController::AppModel.make(space: space, name: 'theta')

        ascending = %w[alpha delta gamma theta zed]
        descending = ascending.reverse

        # ASCENDING
        get '/v3/apps?order_by=name', nil, user_header
        expect(last_response.status).to eq(200)
        parsed_response = Oj.load(last_response.body)
        app_names = parsed_response['resources'].pluck('name')
        expect(app_names).to eq(ascending)
        expect(parsed_response['pagination']['first']['href']).to include("order_by=#{CGI.escape('+')}name")

        # DESCENDING
        get '/v3/apps?order_by=-name', nil, user_header
        expect(last_response.status).to eq(200)
        parsed_response = Oj.load(last_response.body)
        app_names = parsed_response['resources'].pluck('name')
        expect(app_names).to eq(descending)
        expect(parsed_response['pagination']['first']['href']).to include('order_by=-name')
      end

      it 'can order by state' do
        VCAP::CloudController::AppModel.make(space: space, desired_state: 'STARTED')
        VCAP::CloudController::AppModel.make(space: space, desired_state: 'STOPPED')
        VCAP::CloudController::AppModel.make(space: space, desired_state: 'STARTED')
        VCAP::CloudController::AppModel.make(space: space, desired_state: 'STOPPED')
        ascending = %w[STARTED STARTED STOPPED STOPPED]
        descending = ascending.reverse

        # ASCENDING
        get '/v3/apps?order_by=state', nil, user_header
        expect(last_response.status).to eq(200)
        parsed_response = Oj.load(last_response.body)
        app_states = parsed_response['resources'].pluck('state')
        expect(app_states).to eq(ascending)
        expect(parsed_response['pagination']['first']['href']).to include("order_by=#{CGI.escape('+')}state")

        # DESCENDING
        get '/v3/apps?order_by=-state', nil, user_header
        expect(last_response.status).to eq(200)
        parsed_response = Oj.load(last_response.body)
        app_states = parsed_response['resources'].pluck('state')
        expect(app_states).to eq(descending)
        expect(parsed_response['pagination']['first']['href']).to include('order_by=-state')
      end
    end

    context 'labels' do
      let!(:app1) { VCAP::CloudController::AppModel.make(name: 'name1') }
      let!(:app1_label) { VCAP::CloudController::AppLabelModel.make(resource_guid: app1.guid, key_name: 'foo', value: 'bar') }

      let!(:app2) { VCAP::CloudController::AppModel.make(name: 'name2') }
      let!(:app2_label) { VCAP::CloudController::AppLabelModel.make(resource_guid: app2.guid, key_name: 'foo', value: 'funky') }
      let!(:app2__exclusive_label) { VCAP::CloudController::AppLabelModel.make(resource_guid: app2.guid, key_name: 'santa', value: 'claus') }

      let(:admin_header) { headers_for(user, scopes: %w[cloud_controller.admin]) }

      it 'returns a 200 and the filtered apps for "in" label selector' do
        get '/v3/apps?label_selector=foo in (bar)', nil, admin_header

        parsed_response = Oj.load(last_response.body)

        expected_pagination = {
          'total_results' => 1,
          'total_pages' => 1,
          'first' => { 'href' => "#{link_prefix}/v3/apps?label_selector=foo+in+%28bar%29&page=1&per_page=50" },
          'last' => { 'href' => "#{link_prefix}/v3/apps?label_selector=foo+in+%28bar%29&page=1&per_page=50" },
          'next' => nil,
          'previous' => nil
        }

        expect(last_response.status).to eq(200)
        expect(parsed_response['resources'].pluck('guid')).to contain_exactly(app1.guid)
        expect(parsed_response['pagination']).to eq(expected_pagination)
      end

      it 'returns a 200 and the filtered apps for "notin" label selector' do
        get '/v3/apps?label_selector=foo notin (bar)', nil, admin_header

        parsed_response = Oj.load(last_response.body)

        expected_pagination = {
          'total_results' => 1,
          'total_pages' => 1,
          'first' => { 'href' => "#{link_prefix}/v3/apps?label_selector=foo+notin+%28bar%29&page=1&per_page=50" },
          'last' => { 'href' => "#{link_prefix}/v3/apps?label_selector=foo+notin+%28bar%29&page=1&per_page=50" },
          'next' => nil,
          'previous' => nil
        }

        expect(last_response.status).to eq(200)
        expect(parsed_response['resources'].pluck('guid')).to contain_exactly(app2.guid)
        expect(parsed_response['pagination']).to eq(expected_pagination)
      end

      it 'returns a 200 and the filtered apps for "=" label selector' do
        get '/v3/apps?label_selector=foo=bar', nil, admin_header

        parsed_response = Oj.load(last_response.body)

        expected_pagination = {
          'total_results' => 1,
          'total_pages' => 1,
          'first' => { 'href' => "#{link_prefix}/v3/apps?label_selector=foo%3Dbar&page=1&per_page=50" },
          'last' => { 'href' => "#{link_prefix}/v3/apps?label_selector=foo%3Dbar&page=1&per_page=50" },
          'next' => nil,
          'previous' => nil
        }

        expect(last_response.status).to eq(200)
        expect(parsed_response['resources'].pluck('guid')).to contain_exactly(app1.guid)
        expect(parsed_response['pagination']).to eq(expected_pagination)
      end

      it 'returns a 200 and the filtered apps for "==" label selector' do
        get '/v3/apps?label_selector=foo==bar', nil, admin_header

        parsed_response = Oj.load(last_response.body)

        expected_pagination = {
          'total_results' => 1,
          'total_pages' => 1,
          'first' => { 'href' => "#{link_prefix}/v3/apps?label_selector=foo%3D%3Dbar&page=1&per_page=50" },
          'last' => { 'href' => "#{link_prefix}/v3/apps?label_selector=foo%3D%3Dbar&page=1&per_page=50" },
          'next' => nil,
          'previous' => nil
        }

        expect(last_response.status).to eq(200)
        expect(parsed_response['resources'].pluck('guid')).to contain_exactly(app1.guid)
        expect(parsed_response['pagination']).to eq(expected_pagination)
      end

      it 'returns a 200 and the filtered apps for "!=" label selector' do
        get '/v3/apps?label_selector=foo!=bar', nil, admin_header

        parsed_response = Oj.load(last_response.body)

        expected_pagination = {
          'total_results' => 1,
          'total_pages' => 1,
          'first' => { 'href' => "#{link_prefix}/v3/apps?label_selector=foo%21%3Dbar&page=1&per_page=50" },
          'last' => { 'href' => "#{link_prefix}/v3/apps?label_selector=foo%21%3Dbar&page=1&per_page=50" },
          'next' => nil,
          'previous' => nil
        }

        expect(last_response.status).to eq(200)
        expect(parsed_response['resources'].pluck('guid')).to contain_exactly(app2.guid)
        expect(parsed_response['pagination']).to eq(expected_pagination)
      end

      it 'returns a 200 and the filtered apps for "==" label selector' do
        get '/v3/apps?label_selector=foo=funky,santa=claus', nil, admin_header

        parsed_response = Oj.load(last_response.body)

        expected_pagination = {
          'total_results' => 1,
          'total_pages' => 1,
          'first' => { 'href' => "#{link_prefix}/v3/apps?label_selector=foo%3Dfunky%2Csanta%3Dclaus&page=1&per_page=50" },
          'last' => { 'href' => "#{link_prefix}/v3/apps?label_selector=foo%3Dfunky%2Csanta%3Dclaus&page=1&per_page=50" },
          'next' => nil,
          'previous' => nil
        }

        expect(last_response.status).to eq(200)
        expect(parsed_response['resources'].pluck('guid')).to contain_exactly(app2.guid)
        expect(parsed_response['pagination']).to eq(expected_pagination)
      end

      it 'returns a 200 and the filtered apps for existence label selector' do
        get '/v3/apps?label_selector=santa', nil, admin_header

        parsed_response = Oj.load(last_response.body)

        expected_pagination = {
          'total_results' => 1,
          'total_pages' => 1,
          'first' => { 'href' => "#{link_prefix}/v3/apps?label_selector=santa&page=1&per_page=50" },
          'last' => { 'href' => "#{link_prefix}/v3/apps?label_selector=santa&page=1&per_page=50" },
          'next' => nil,
          'previous' => nil
        }

        expect(last_response.status).to eq(200)
        expect(parsed_response['resources'].pluck('guid')).to contain_exactly(app2.guid)
        expect(parsed_response['pagination']).to eq(expected_pagination)
      end

      it 'returns a 200 and the filtered apps for non-existence label selector' do
        get '/v3/apps?label_selector=!santa', nil, admin_header

        parsed_response = Oj.load(last_response.body)

        expected_pagination = {
          'total_results' => 1,
          'total_pages' => 1,
          'first' => { 'href' => "#{link_prefix}/v3/apps?label_selector=%21santa&page=1&per_page=50" },
          'last' => { 'href' => "#{link_prefix}/v3/apps?label_selector=%21santa&page=1&per_page=50" },
          'next' => nil,
          'previous' => nil
        }

        expect(last_response.status).to eq(200)
        expect(parsed_response['resources'].pluck('guid')).to contain_exactly(app1.guid)
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

      let(:admin_header) { headers_for(user, scopes: %w[cloud_controller.admin]) }

      it 'returns a 200 and the correct app when querying with space guid' do
        get "/v3/apps?space_guids=#{space2.guid}&label_selector=foo==funky", nil, admin_header

        parsed_response = Oj.load(last_response.body)

        expected_pagination = {
          'total_results' => 1,
          'total_pages' => 1,
          'first' => { 'href' => "#{link_prefix}/v3/apps?label_selector=foo%3D%3Dfunky&page=1&per_page=50&space_guids=#{space2.guid}" },
          'last' => { 'href' => "#{link_prefix}/v3/apps?label_selector=foo%3D%3Dfunky&page=1&per_page=50&space_guids=#{space2.guid}" },
          'next' => nil,
          'previous' => nil
        }

        expect(last_response.status).to eq(200)
        expect(parsed_response['resources'].pluck('guid')).to contain_exactly(app2.guid)
        expect(parsed_response['pagination']).to eq(expected_pagination)
      end

      it 'returns a 200 and the correct app when querying with space guid' do
        get "/v3/apps?space_guids=#{space2.guid}&label_selector=fruit==strawberry&names=name2", nil, admin_header

        parsed_response = Oj.load(last_response.body)

        expected_pagination = {
          'total_results' => 1,
          'total_pages' => 1,
          'first' => { 'href' => "#{link_prefix}/v3/apps?label_selector=fruit%3D%3Dstrawberry&names=name2&page=1&per_page=50&space_guids=#{space2.guid}" },
          'last' => { 'href' => "#{link_prefix}/v3/apps?label_selector=fruit%3D%3Dstrawberry&names=name2&page=1&per_page=50&space_guids=#{space2.guid}" },
          'next' => nil,
          'previous' => nil
        }

        expect(last_response.status).to eq(200)
        expect(parsed_response['resources'].pluck('guid')).to contain_exactly(app2.guid)
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

        get '/v3/apps?per_page=2&include=space,space.organization', nil, admin_header
        expect(last_response.status).to eq(200)

        parsed_response = Oj.load(last_response.body)

        expect(parsed_response['included']['organizations'][0]).to be_a_response_like({
                                                                                        'guid' => org1.guid,
                                                                                        'created_at' => iso8601,
                                                                                        'updated_at' => iso8601,
                                                                                        'name' => org1.name,
                                                                                        'metadata' => {
                                                                                          'labels' => {},
                                                                                          'annotations' => {}
                                                                                        },
                                                                                        'suspended' => false,
                                                                                        'links' => {
                                                                                          'self' => {
                                                                                            'href' => "#{link_prefix}/v3/organizations/#{org1.guid}"
                                                                                          },
                                                                                          'default_domain' => {
                                                                                            'href' => "#{link_prefix}/v3/organizations/#{org1.guid}/domains/default"
                                                                                          },
                                                                                          'domains' => {
                                                                                            'href' => "#{link_prefix}/v3/organizations/#{org1.guid}/domains"
                                                                                          },
                                                                                          'quota' => {
                                                                                            'href' => "#{link_prefix}/v3/organization_quotas/#{org1.quota_definition.guid}"
                                                                                          }
                                                                                        },
                                                                                        'relationships' => { 'quota' => { 'data' => { 'guid' => org1.quota_definition.guid } } }
                                                                                      })
        expect(parsed_response['included']['organizations'][1]).to be_a_response_like({
                                                                                        'guid' => org2.guid,
                                                                                        'created_at' => iso8601,
                                                                                        'updated_at' => iso8601,
                                                                                        'name' => org2.name,
                                                                                        'suspended' => false,
                                                                                        'metadata' => {
                                                                                          'labels' => {},
                                                                                          'annotations' => {}
                                                                                        },
                                                                                        'links' => {
                                                                                          'self' => {
                                                                                            'href' => "#{link_prefix}/v3/organizations/#{org2.guid}"
                                                                                          },
                                                                                          'default_domain' => {
                                                                                            'href' => "#{link_prefix}/v3/organizations/#{org2.guid}/domains/default"
                                                                                          },
                                                                                          'domains' => {
                                                                                            'href' => "#{link_prefix}/v3/organizations/#{org2.guid}/domains"
                                                                                          },
                                                                                          'quota' => {
                                                                                            'href' => "#{link_prefix}/v3/organization_quotas/#{org2.quota_definition.guid}"
                                                                                          }
                                                                                        },
                                                                                        'relationships' => { 'quota' => { 'data' => { 'guid' => org2.quota_definition.guid } } }
                                                                                      })
      end

      it 'flags unsupported includes that contain supported ones' do
        get '/v3/apps?per_page=2&include=space.organization,spaceship,borgs,space', nil, admin_header
        expect(last_response.status).to eq(400)
      end

      it 'does not include spaces if no one asks for them' do
        get '/v3/apps', nil, admin_header
        parsed_response = Oj.load(last_response.body)
        expect(parsed_response).not_to have_key('included')
      end
    end

    context 'when including orgs' do
      before do
        VCAP::CloudController::AppModel.make
      end

      it 'eagerly loads spaces to efficiently access space.organization_id' do
        expect(VCAP::CloudController::IncludeOrganizationDecorator).to receive(:decorate) do |_, resources|
          expect(resources).not_to be_empty
          resources.each { |r| expect(r.associations).to include(:space) }
        end

        get '/v3/apps?include=space.organization', nil, admin_header
        expect(last_response).to have_status_code(200)
      end
    end
  end
end
