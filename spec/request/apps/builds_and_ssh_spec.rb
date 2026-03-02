require 'spec_helper'
require 'actions/process_create_from_app_droplet'
require 'request_spec_shared_examples'
require_relative 'shared_context'

# Split from spec/request/apps_spec.rb for better test parallelization

RSpec.describe 'Apps' do
  include_context 'apps request spec'

  describe 'GET /v3/apps/:guid/builds' do
    let(:app_model) { VCAP::CloudController::AppModel.make(space: space, name: 'my-app') }
    let(:build) do
      VCAP::CloudController::BuildModel.make(
        package: package,
        app: app_model,
        staging_memory_in_mb: 123,
        staging_disk_in_mb: 456,
        staging_log_rate_limit: 789,
        created_by_user_name: 'bob the builder',
        created_by_user_guid: user.guid,
        created_by_user_email: 'bob@loblaw.com'
      )
    end
    let!(:second_build) do
      VCAP::CloudController::BuildModel.make(
        package: package,
        app: app_model,
        staging_memory_in_mb: 123,
        staging_disk_in_mb: 456,
        staging_log_rate_limit: 789,
        created_at: build.created_at - 1.day,
        created_by_user_name: 'bob the builder',
        created_by_user_guid: user.guid,
        created_by_user_email: 'bob@loblaw.com'
      )
    end
    let(:package) { VCAP::CloudController::PackageModel.make(app_guid: app_model.guid) }
    let(:droplet) do
      VCAP::CloudController::DropletModel.make(
        state: VCAP::CloudController::DropletModel::STAGED_STATE,
        package_guid: package.guid,
        build: build
      )
    end
    let(:second_droplet) do
      VCAP::CloudController::DropletModel.make(
        state: VCAP::CloudController::DropletModel::STAGED_STATE,
        package_guid: package.guid,
        build: second_build
      )
    end
    let(:body) do
      {
        lifecycle: {
          type: 'buildpack',
          data: {
            buildpacks: ['http://github.com/myorg/awesome-buildpack'],
            stack: 'cflinuxfs4'
          }
        }
      }
    end

    describe 'permissions' do
      let(:api_call) do
        ->(headers) { get "/v3/apps/#{app_model.guid}/builds", nil, headers }
      end
      let(:expected_codes_and_responses) do
        h = Hash.new({ code: 200, response_guids: [build.guid, second_build.guid] }.freeze)
        h['org_auditor'] = { code: 404 }
        h['org_billing_manager'] = { code: 404 }
        h['no_role'] = { code: 404 }
        h
      end

      it_behaves_like 'permissions for list endpoint', ALL_PERMISSIONS
    end

    describe 'as a developer' do
      let(:staging_message) { VCAP::CloudController::BuildCreateMessage.new(body) }
      let(:per_page) { 2 }
      let(:order_by) { '-created_at' }

      before do
        space.organization.add_user(user)
        space.add_developer(user)
        VCAP::CloudController::BuildpackLifecycle.new(package, staging_message).create_lifecycle_data_model(build)
        VCAP::CloudController::BuildpackLifecycle.new(package, staging_message).create_lifecycle_data_model(second_build)
        build.update(state: droplet.state, error_description: droplet.error_description)
        second_build.update(state: second_droplet.state, error_description: second_droplet.error_description)
      end

      it 'lists the builds for app' do
        get "v3/apps/#{app_model.guid}/builds?order_by=#{order_by}&per_page=#{per_page}", nil, user_header

        parsed_response = Oj.load(last_response.body)

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
                                                          'previous' => nil
                                                        },
                                                        'resources' => [
                                                          {
                                                            'guid' => build.guid,
                                                            'created_at' => iso8601,
                                                            'updated_at' => iso8601,
                                                            'state' => 'STAGED',
                                                            'error' => nil,
                                                            'staging_memory_in_mb' => 123,
                                                            'staging_disk_in_mb' => 456,
                                                            'staging_log_rate_limit_bytes_per_second' => 789,
                                                            'lifecycle' => {
                                                              'type' => 'buildpack',
                                                              'data' => {
                                                                'buildpacks' => ['http://github.com/myorg/awesome-buildpack'],
                                                                'stack' => 'cflinuxfs4'
                                                              }
                                                            },
                                                            'package' => { 'guid' => package.guid },
                                                            'droplet' => {
                                                              'guid' => droplet.guid
                                                            },
                                                            'relationships' => { 'app' => { 'data' => { 'guid' => app_model.guid } } },
                                                            'metadata' => { 'labels' => {}, 'annotations' => {} },
                                                            'links' => {
                                                              'self' => { 'href' => "#{link_prefix}/v3/builds/#{build.guid}" },
                                                              'app' => { 'href' => "#{link_prefix}/v3/apps/#{package.app.guid}" },
                                                              'droplet' => { 'href' => "#{link_prefix}/v3/droplets/#{droplet.guid}" }
                                                            },
                                                            'created_by' => { 'guid' => user.guid, 'name' => 'bob the builder', 'email' => 'bob@loblaw.com' }
                                                          },
                                                          {
                                                            'guid' => second_build.guid,
                                                            'created_at' => iso8601,
                                                            'updated_at' => iso8601,
                                                            'state' => 'STAGED',
                                                            'error' => nil,
                                                            'staging_memory_in_mb' => 123,
                                                            'staging_disk_in_mb' => 456,
                                                            'staging_log_rate_limit_bytes_per_second' => 789,
                                                            'lifecycle' => {
                                                              'type' => 'buildpack',
                                                              'data' => {
                                                                'buildpacks' => ['http://github.com/myorg/awesome-buildpack'],
                                                                'stack' => 'cflinuxfs4'
                                                              }
                                                            },
                                                            'package' => { 'guid' => package.guid },
                                                            'droplet' => {
                                                              'guid' => second_droplet.guid
                                                            },
                                                            'relationships' => { 'app' => { 'data' => { 'guid' => app_model.guid } } },
                                                            'metadata' => { 'labels' => {}, 'annotations' => {} },
                                                            'links' => {
                                                              'self' => { 'href' => "#{link_prefix}/v3/builds/#{second_build.guid}" },
                                                              'app' => { 'href' => "#{link_prefix}/v3/apps/#{package.app.guid}" },
                                                              'droplet' => { 'href' => "#{link_prefix}/v3/droplets/#{second_droplet.guid}" }
                                                            },
                                                            'created_by' => { 'guid' => user.guid, 'name' => 'bob the builder', 'email' => 'bob@loblaw.com' }
                                                          }
                                                        ]
                                                      })
      end

      it_behaves_like 'list_endpoint_with_common_filters' do
        let(:resource_klass) { VCAP::CloudController::BuildModel }
        let(:additional_resource_params) { { app: app_model } }
        let(:api_call) do
          ->(headers, filters) { get "/v3/apps/#{app_model.guid}/builds?#{filters}", nil, headers }
        end
        let(:headers) { admin_header }
      end

      it 'filters on label_selector' do
        VCAP::CloudController::BuildLabelModel.make(key_name: 'fruit', value: 'strawberry', build: build)

        get "/v3/apps/#{app_model.guid}/builds?label_selector=fruit=strawberry", {}, user_header

        expect(last_response.status).to eq(200)
        expect(parsed_response['resources'].count).to eq(1)
        expect(parsed_response['resources'][0]['guid']).to eq(build.guid)
      end
    end
  end

  describe 'GET /v3/apps/:guid/ssh_enabled' do
    before do
      space.organization.add_user(user)
    end

    context 'when getting an apps ssh_enabled value' do
      let(:api_call) { ->(user_headers) { get "/v3/apps/#{app_model.guid}/ssh_enabled", nil, user_headers } }
      let!(:app_model) do
        VCAP::CloudController::AppModel.make(
          :buildpack,
          name: 'my_app',
          guid: 'app1_guid',
          space: space
        )
      end

      let(:expected_codes_and_responses) do
        h = Hash.new({ code: 200 }.freeze)
        h['org_auditor'] = { code: 404 }
        h['org_billing_manager'] = { code: 404 }
        h['no_role'] = { code: 404 }
        h
      end

      it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS
    end
  end
end
