require 'spec_helper'
require 'request_spec_shared_examples'

RSpec.describe 'Droplets' do
  let(:space) { VCAP::CloudController::Space.make }
  let(:org) { space.organization }
  let(:user) { VCAP::CloudController::User.make }
  let(:app_model) { VCAP::CloudController::AppModel.make(space_guid: space.guid, name: 'my-app') }
  let(:other_app_model) { VCAP::CloudController::AppModel.make(space_guid: space.guid, name: 'my-app-3') }
  let(:developer) { make_developer_for_space(space) }
  let(:developer_headers) { headers_for(developer, user_name: user_name) }
  let(:user_name) { 'sundance kid' }

  let(:parsed_response) { MultiJson.load(last_response.body) }

  describe 'POST /v3/droplets' do
    let(:user) { VCAP::CloudController::User.make }

    let(:params) do
      {
        process_types: {
          web: 'please_run_my_process.sh'
        },
        relationships: {
          app: {
            data: { guid: app_model.guid }
          }
        }
      }
    end

    describe 'when creating a droplet' do
      it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS do
        let(:api_call) { lambda { |user_headers| post '/v3/droplets', params.to_json, user_headers } }

        let(:droplet_json) do
          {
            guid: UUID_REGEX,
            state: 'AWAITING_UPLOAD',
            error: nil,
            lifecycle: {
              type: 'buildpack',
              data: {}
            },
            execution_metadata: '',
            process_types: {
              web: 'please_run_my_process.sh'
            },
            checksum: nil,
            buildpacks: [],
            stack: nil,
            image: nil,
            created_at: iso8601,
            updated_at: iso8601,
            relationships: { app: { data: { guid: app_model.guid } } },
            metadata: {
              labels: {},
              annotations: {}
            },
            links: {
              self: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/droplets\/#{UUID_REGEX}) },
              app: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/apps\/#{UUID_REGEX}) },
              assign_current_droplet: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/apps\/#{UUID_REGEX}\/relationships\/current_droplet), method: 'PATCH' },
              upload: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/droplets\/#{UUID_REGEX}\/upload), method: 'POST' }
            }
          }
        end

        let(:expected_codes_and_responses) do
          h = Hash.new(
            code: 403
          )
          h['org_auditor'] = {
            code: 422
          }
          h['org_billing_manager'] = {
            code: 422
          }
          h['no_role'] = {
            code: 422
          }
          h['admin'] = {
            code: 201,
            response_object: droplet_json
          }
          h['space_developer'] = {
            code: 201,
            response_object: droplet_json
          }
          h.freeze
        end

        let(:expected_event_hash) do
          {
            type: 'audit.app.droplet.create',
            actee: app_model.guid,
            actee_type: 'app',
            actee_name: app_model.name,
            metadata: { droplet_guid: parsed_response['guid'] }.to_json,
            space_guid: space.guid,
            organization_guid: org.guid,
          }
        end
      end
    end

    describe 'when the user is not logged in' do
      it 'returns 401 for Unauthenticated requests' do
        post '/v3/droplets', params.to_json, base_json_headers
        expect(last_response.status).to eq(401)
      end
    end

    context 'when the user does not have the required scopes' do
      let(:user_header) { headers_for(user, scopes: ['cloud_controller.read']) }

      it 'returns a 403' do
        post '/v3/droplets', params.to_json, user_header
        expect(last_response.status).to eq(403)
      end
    end

    context 'when params are invalid' do
      let(:invalid_params) do
        {
          process_types: 867,
          relationships: {
            app: {
              data: { guid: app_model.guid }
            }
          }
        }
      end
      it 'returns a 422 with an appropriate error message' do
        post '/v3/droplets', invalid_params.to_json, developer_headers
        expect(last_response.status).to eq(422)
        expect(last_response).to have_error_message(/must be a hash/)
      end
    end

    context 'when app does not exist' do
      let(:nonexistent_app_params) do
        {
          relationships: {
            app: {
              data: { guid: 'not-app-guid' }
            }
          }
        }
      end
      it 'returns a 422 with an appropriate error message' do
        post '/v3/droplets', nonexistent_app_params.to_json, developer_headers
        expect(last_response.status).to eq(422)
        expect(last_response).to have_error_message(/App with guid "not-app-guid" does not exist, or you do not have access to it./)
      end
    end

    context 'when user cannot see the app' do
      let(:other_user) { VCAP::CloudController::User.make }

      before { set_current_user(other_user) }

      it 'returns a 422 with an appropriate error message' do
        post '/v3/droplets', params.to_json, headers_for(other_user)
        expect(last_response.status).to eq(422)
        expect(last_response).to have_error_message("App with guid \"#{app_model.guid}\" does not exist, or you do not have access to it.")
      end
    end

    context 'when the app has a docker lifecycle' do
      let!(:docker_app) { VCAP::CloudController::AppModel.make(:docker, space: space) }

      let(:docker_app_params) do
        {
          relationships: {
            app: {
              data: { guid: docker_app.guid }
            }
          }
        }
      end

      it 'returns a 422 with an appropriate error message' do
        post '/v3/droplets', docker_app_params.to_json, developer_headers
        expect(last_response.status).to eq(422)
        expect(last_response).to have_error_message('Droplet creation is not available for apps with docker lifecycles.')
      end
    end
  end

  describe 'GET /v3/droplets/:guid' do
    let(:guid) { droplet_model.guid }
    let(:package_model) { VCAP::CloudController::PackageModel.make(app_guid: app_model.guid) }
    let(:app_guid) { droplet_model.app_guid }

    context 'when the droplet has a buildpack lifecycle' do
      let!(:droplet_model) do
        VCAP::CloudController::DropletModel.make(
          state: VCAP::CloudController::DropletModel::STAGED_STATE,
          app_guid: app_model.guid,
          package_guid: package_model.guid,
          buildpack_receipt_buildpack: 'http://buildpack.git.url.com',
          error_description: 'example error',
          execution_metadata: 'some-data',
          droplet_hash: 'shalalala',
          sha256_checksum: 'droplet-checksum-sha256',
          process_types: { 'web' => 'start-command' },
        )
      end

      before do
        droplet_model.buildpack_lifecycle_data.update(buildpacks: [{ key: 'http://buildpack.git.url.com', version: '0.3', name: 'git' }], stack: 'stack-name')
      end

      it 'gets a droplet' do
        get "/v3/droplets/#{droplet_model.guid}", nil, developer_headers

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
          'checksum' => { 'type' => 'sha256', 'value' => 'droplet-checksum-sha256' },
          'buildpacks' => [{ 'name' => 'http://buildpack.git.url.com', 'detect_output' => nil, 'version' => '0.3', 'buildpack_name' => 'git' }],
          'stack' => 'stack-name',
          'execution_metadata' => 'some-data',
          'process_types' => { 'web' => 'start-command' },
          'image' => nil,
          'created_at' => iso8601,
          'updated_at' => iso8601,
          'relationships' => { 'app' => { 'data' => { 'guid' => app_model.guid } } },
          'links' => {
            'self' => { 'href' => "#{link_prefix}/v3/droplets/#{guid}" },
            'package' => { 'href' => "#{link_prefix}/v3/packages/#{package_model.guid}" },
            'app' => { 'href' => "#{link_prefix}/v3/apps/#{app_guid}" },
            'assign_current_droplet' => { 'href' => "#{link_prefix}/v3/apps/#{app_guid}/relationships/current_droplet", 'method' => 'PATCH' },
          },
          'metadata' => {
            'labels' => {},
            'annotations' => {},
          },
        })
      end

      it 'redacts information for auditors' do
        auditor = VCAP::CloudController::User.make
        space.organization.add_user(auditor)
        space.add_auditor(auditor)

        get "/v3/droplets/#{droplet_model.guid}", nil, headers_for(auditor)

        parsed_response = MultiJson.load(last_response.body)

        expect(last_response.status).to eq(200)
        expect(parsed_response['process_types']).to eq({ 'redacted_message' => '[PRIVATE DATA HIDDEN]' })
        expect(parsed_response['execution_metadata']).to eq('[PRIVATE DATA HIDDEN]')
      end
    end

    context 'when the droplet has a docker lifecycle' do
      let!(:droplet_model) do
        VCAP::CloudController::DropletModel.make(
          :docker,
          state: VCAP::CloudController::DropletModel::STAGED_STATE,
          app_guid: app_model.guid,
          package_guid: package_model.guid,
          error_description: 'example error',
          execution_metadata: 'some-data',
          process_types: { 'web' => 'start-command' },
          docker_receipt_image: 'docker/foobar:baz'
        )
      end

      it 'gets a droplet' do
        get "/v3/droplets/#{droplet_model.guid}", nil, developer_headers

        parsed_response = MultiJson.load(last_response.body)

        expect(last_response.status).to eq(200)
        expect(parsed_response).to be_a_response_like({
          'guid' => droplet_model.guid,
          'state' => VCAP::CloudController::DropletModel::STAGED_STATE,
          'error' => 'example error',
          'lifecycle' => {
            'type' => 'docker',
            'data' => {}
          },
          'checksum' => nil,
          'buildpacks' => nil,
          'stack' => nil,
          'execution_metadata' => 'some-data',
          'process_types' => { 'web' => 'start-command' },
          'image' => 'docker/foobar:baz',
          'created_at' => iso8601,
          'updated_at' => iso8601,
          'relationships' => { 'app' => { 'data' => { 'guid' => app_model.guid } } },
          'links' => {
            'self' => { 'href' => "#{link_prefix}/v3/droplets/#{guid}" },
            'package' => { 'href' => "#{link_prefix}/v3/packages/#{package_model.guid}" },
            'app' => { 'href' => "#{link_prefix}/v3/apps/#{app_guid}" },
            'assign_current_droplet' => { 'href' => "#{link_prefix}/v3/apps/#{app_guid}/relationships/current_droplet", 'method' => 'PATCH' },
          },
          'metadata' => {
            'labels' => {},
            'annotations' => {}
          },
        })
      end
    end
  end

  describe 'GET /v3/droplets' do
    let(:buildpack) { VCAP::CloudController::Buildpack.make }
    let(:package_model) do
      VCAP::CloudController::PackageModel.make(
        app_guid: app_model.guid,
        type: VCAP::CloudController::PackageModel::BITS_TYPE
      )
    end

    let!(:droplet1) do
      VCAP::CloudController::DropletModel.make(
        app_guid: app_model.guid,
        created_at: Time.at(1),
        package_guid: package_model.guid,
        droplet_hash: nil,
        sha256_checksum: nil,
        buildpack_receipt_buildpack: buildpack.name,
        buildpack_receipt_buildpack_guid: buildpack.guid,
        staging_disk_in_mb: 235,
        error_description: 'example-error',
        state: VCAP::CloudController::DropletModel::FAILED_STATE
      )
    end
    let!(:droplet2) do
      VCAP::CloudController::DropletModel.make(
        app_guid: app_model.guid,
        created_at: Time.at(2),
        package_guid: package_model.guid,
        droplet_hash: 'my-hash',
        sha256_checksum: 'droplet-checksum-sha256',
        buildpack_receipt_buildpack: 'http://buildpack.git.url.com',
        state: VCAP::CloudController::DropletModel::STAGED_STATE,
        process_types: { 'web' => 'started' },
        execution_metadata: 'black-box-secrets',
        error_description: 'example-error'
      )
    end

    let(:per_page) { 2 }
    let(:order_by) { '-created_at' }

    before do
      droplet1.buildpack_lifecycle_data.update(buildpacks: [buildpack.name], stack: 'stack-1')
      droplet2.buildpack_lifecycle_data.update(buildpacks: ['http://buildpack.git.url.com'], stack: 'stack-2')
    end

    it 'list all droplets with a buildpack lifecycle' do
      get "/v3/droplets?order_by=#{order_by}&per_page=#{per_page}", nil, developer_headers
      expect(last_response.status).to eq(200)
      expect(parsed_response['resources']).to include(hash_including('guid' => droplet1.guid))
      expect(parsed_response['resources']).to include(hash_including('guid' => droplet2.guid))
      expect(parsed_response).to be_a_response_like({
        'pagination' => {
          'total_results' => 2,
          'total_pages' => 1,
          'first' => { 'href' => "#{link_prefix}/v3/droplets?order_by=#{order_by}&page=1&per_page=2" },
          'last' => { 'href' => "#{link_prefix}/v3/droplets?order_by=#{order_by}&page=1&per_page=2" },
          'next' => nil,
          'previous' => nil,
        },
        'resources' => [
          {
            'guid' => droplet2.guid,
            'state' => VCAP::CloudController::DropletModel::STAGED_STATE,
            'error' => 'example-error',
            'lifecycle' => {
              'type' => 'buildpack',
              'data' => {}
            },
            'image' => nil,
            'checksum' => { 'type' => 'sha256', 'value' => 'droplet-checksum-sha256' },
            'buildpacks' => [{ 'name' => 'http://buildpack.git.url.com', 'detect_output' => nil, 'buildpack_name' => nil, 'version' => nil }],
            'stack' => 'stack-2',
            'execution_metadata' => '[PRIVATE DATA HIDDEN IN LISTS]',
            'process_types' => { 'redacted_message' => '[PRIVATE DATA HIDDEN IN LISTS]' },
            'created_at' => iso8601,
            'updated_at' => iso8601,
            'relationships' => { 'app' => { 'data' => { 'guid' => app_model.guid } } },
            'links' => {
              'self' => { 'href' => "#{link_prefix}/v3/droplets/#{droplet2.guid}" },
              'package' => { 'href' => "#{link_prefix}/v3/packages/#{package_model.guid}" },
              'app' => { 'href' => "#{link_prefix}/v3/apps/#{app_model.guid}" },
              'assign_current_droplet' => { 'href' => "#{link_prefix}/v3/apps/#{app_model.guid}/relationships/current_droplet", 'method' => 'PATCH' },
            },
            'metadata' => {
              'labels' => {},
              'annotations' => {}
            },
          },
          {
            'guid' => droplet1.guid,
            'state' => VCAP::CloudController::DropletModel::FAILED_STATE,
            'error' => 'example-error',
            'lifecycle' => {
              'type' => 'buildpack',
              'data' => {}
            },
            'image' => nil,
            'checksum' => nil,
            'buildpacks' => [{ 'name' => buildpack.name, 'detect_output' => nil, 'buildpack_name' => nil, 'version' => nil }],
            'stack' => 'stack-1',
            'execution_metadata' => '[PRIVATE DATA HIDDEN IN LISTS]',
            'process_types' => { 'redacted_message' => '[PRIVATE DATA HIDDEN IN LISTS]' },
            'created_at' => iso8601,
            'updated_at' => iso8601,
            'relationships' => { 'app' => { 'data' => { 'guid' => app_model.guid } } },
            'links' => {
              'self' => { 'href' => "#{link_prefix}/v3/droplets/#{droplet1.guid}" },
              'package' => { 'href' => "#{link_prefix}/v3/packages/#{package_model.guid}" },
              'app' => { 'href' => "#{link_prefix}/v3/apps/#{app_model.guid}" },
              'assign_current_droplet' => { 'href' => "#{link_prefix}/v3/apps/#{app_model.guid}/relationships/current_droplet", 'method' => 'PATCH' },
            },
            'metadata' => {
              'labels' => {},
              'annotations' => {}
            },
          }
        ]
      })
    end

    context 'when a droplet does not have a buildpack lifecycle' do
      let!(:droplet_without_lifecycle) { VCAP::CloudController::DropletModel.make(:buildpack, package_guid: VCAP::CloudController::PackageModel.make.guid) }

      it 'is excluded' do
        get '/v3/droplets', nil, developer_headers
        expect(parsed_response['resources']).not_to include(hash_including('guid' => droplet_without_lifecycle.guid))
      end
    end

    context 'faceted list' do
      let(:space2) { VCAP::CloudController::Space.make }
      let(:app_model2) { VCAP::CloudController::AppModel.make(space: space) }
      let(:app_model3) { VCAP::CloudController::AppModel.make(space: space2) }
      let!(:droplet3) { VCAP::CloudController::DropletModel.make(app: app_model2, state: VCAP::CloudController::DropletModel::FAILED_STATE) }
      let!(:droplet4) { VCAP::CloudController::DropletModel.make(app: app_model3, state: VCAP::CloudController::DropletModel::FAILED_STATE) }

      it 'filters by states' do
        get '/v3/droplets?states=STAGED,FAILED', nil, developer_headers

        expect(last_response.status).to eq(200)
        expect(parsed_response['pagination']).to be_a_response_like(
          {
            'total_results' => 3,
            'total_pages' => 1,
            'first' => { 'href' => "#{link_prefix}/v3/droplets?page=1&per_page=50&states=STAGED%2CFAILED" },
            'last' => { 'href' => "#{link_prefix}/v3/droplets?page=1&per_page=50&states=STAGED%2CFAILED" },
            'next' => nil,
            'previous' => nil,
          })

        returned_guids = parsed_response['resources'].map { |i| i['guid'] }
        expect(returned_guids).to match_array([droplet1.guid, droplet2.guid, droplet3.guid])
        expect(returned_guids).not_to include(droplet4.guid)
      end

      it 'filters by app_guids' do
        get "/v3/droplets?app_guids=#{app_model.guid}", nil, developer_headers

        expect(last_response.status).to eq(200)
        expect(parsed_response['pagination']).to be_a_response_like(
          {
            'total_results' => 2,
            'total_pages' => 1,
            'first' => { 'href' => "#{link_prefix}/v3/droplets?app_guids=#{app_model.guid}&page=1&per_page=50" },
            'last' => { 'href' => "#{link_prefix}/v3/droplets?app_guids=#{app_model.guid}&page=1&per_page=50" },
            'next' => nil,
            'previous' => nil,
          })

        returned_guids = parsed_response['resources'].map { |i| i['guid'] }
        expect(returned_guids).to match_array([droplet1.guid, droplet2.guid])
      end

      it 'filters by guids' do
        get "/v3/droplets?guids=#{droplet1.guid}%2C#{droplet3.guid}", nil, developer_headers

        expect(last_response.status).to eq(200)
        expect(parsed_response['pagination']).to be_a_response_like(
          {
            'total_results' => 2,
            'total_pages' => 1,
            'first' => { 'href' => "#{link_prefix}/v3/droplets?guids=#{droplet1.guid}%2C#{droplet3.guid}&page=1&per_page=50" },
            'last' => { 'href' => "#{link_prefix}/v3/droplets?guids=#{droplet1.guid}%2C#{droplet3.guid}&page=1&per_page=50" },
            'next' => nil,
            'previous' => nil,
          })

        returned_guids = parsed_response['resources'].map { |i| i['guid'] }
        expect(returned_guids).to match_array([droplet1.guid, droplet3.guid])
      end

      let(:organization1) { space.organization }
      let(:organization2) { space2.organization }

      it 'filters by organization guids' do
        get "/v3/droplets?organization_guids=#{organization1.guid}", nil, developer_headers

        expect(last_response.status).to eq(200)
        expect(parsed_response['pagination']).to be_a_response_like(
          {
            'total_results' => 3,
            'total_pages' => 1,
            'first' => { 'href' => "#{link_prefix}/v3/droplets?organization_guids=#{organization1.guid}&page=1&per_page=50" },
            'last' => { 'href' => "#{link_prefix}/v3/droplets?organization_guids=#{organization1.guid}&page=1&per_page=50" },
            'next' => nil,
            'previous' => nil,
          })

        returned_guids = parsed_response['resources'].map { |i| i['guid'] }
        expect(returned_guids).to match_array([droplet1.guid, droplet2.guid, droplet3.guid])
      end

      it 'filters by space guids that the developer has access to' do
        get "/v3/droplets?space_guids=#{space.guid}%2C#{space2.guid}", nil, developer_headers

        expect(last_response.status).to eq(200)
        expect(parsed_response['pagination']).to be_a_response_like(
          {
            'total_results' => 3,
            'total_pages' => 1,
            'first' => { 'href' => "#{link_prefix}/v3/droplets?page=1&per_page=50&space_guids=#{space.guid}%2C#{space2.guid}" },
            'last' => { 'href' => "#{link_prefix}/v3/droplets?page=1&per_page=50&space_guids=#{space.guid}%2C#{space2.guid}" },
            'next' => nil,
            'previous' => nil,
          })

        returned_guids = parsed_response['resources'].map { |i| i['guid'] }
        expect(returned_guids).to match_array([droplet1.guid, droplet2.guid, droplet3.guid])
      end
    end

    context 'label_selector' do
      let!(:dropletA) { VCAP::CloudController::DropletModel.make(app_guid: app_model.guid) }
      let!(:dropletAFruit) { VCAP::CloudController::DropletLabelModel.make(key_name: 'fruit', value: 'strawberry', droplet: dropletA) }
      let!(:dropletAAnimal) { VCAP::CloudController::DropletLabelModel.make(key_name: 'animal', value: 'horse', droplet: dropletA) }

      let!(:dropletB) { VCAP::CloudController::DropletModel.make(app_guid: app_model.guid) }
      let!(:dropletBEnv) { VCAP::CloudController::DropletLabelModel.make(key_name: 'env', value: 'prod', droplet: dropletB) }
      let!(:dropletBAnimal) { VCAP::CloudController::DropletLabelModel.make(key_name: 'animal', value: 'dog', droplet: dropletB) }

      let!(:dropletC) { VCAP::CloudController::DropletModel.make(app_guid: app_model.guid) }
      let!(:dropletCEnv) { VCAP::CloudController::DropletLabelModel.make(key_name: 'env', value: 'prod', droplet: dropletC) }
      let!(:dropletCAnimal) { VCAP::CloudController::DropletLabelModel.make(key_name: 'animal', value: 'horse', droplet: dropletC) }

      let!(:dropletD) { VCAP::CloudController::DropletModel.make(app_guid: app_model.guid) }
      let!(:dropletDEnv) { VCAP::CloudController::DropletLabelModel.make(key_name: 'env', value: 'prod', droplet: dropletD) }

      let!(:dropletE) { VCAP::CloudController::DropletModel.make(app_guid: app_model.guid) }
      let!(:dropletEEnv) { VCAP::CloudController::DropletLabelModel.make(key_name: 'env', value: 'staging', droplet: dropletE) }
      let!(:dropletEAnimal) { VCAP::CloudController::DropletLabelModel.make(key_name: 'animal', value: 'dog', droplet: dropletE) }

      it 'returns the matching droplets' do
        get '/v3/droplets?label_selector=!fruit,animal in (dog,horse),env=prod', nil, developer_headers
        expect(last_response.status).to eq(200), last_response.body

        parsed_response = MultiJson.load(last_response.body)
        expect(parsed_response['resources'].map { |r| r['guid'] }).to contain_exactly(dropletB.guid, dropletC.guid)
      end
    end
  end

  describe 'DELETE /v3/droplets/:guid' do
    let!(:droplet) { VCAP::CloudController::DropletModel.make(:buildpack, app_guid: app_model.guid) }

    it 'deletes a droplet asynchronously' do
      delete "/v3/droplets/#{droplet.guid}", nil, developer_headers

      expect(last_response.status).to eq(202)
      expect(last_response.headers['Location']).to match(%r(http.+/v3/jobs/[a-fA-F0-9-]+))

      execute_all_jobs(expected_successes: 2, expected_failures: 0)
      get "/v3/droplets/#{droplet.guid}", {}, developer_headers
      expect(last_response.status).to eq(404)
    end
  end

  describe 'GET /v3/apps/:guid/droplets' do
    let(:buildpack) { VCAP::CloudController::Buildpack.make }
    let(:package_model) do
      VCAP::CloudController::PackageModel.make(
        app_guid: app_model.guid,
        type: VCAP::CloudController::PackageModel::BITS_TYPE
      )
    end

    let!(:droplet1) do
      VCAP::CloudController::DropletModel.make(
        app_guid: app_model.guid,
        created_at: Time.at(1),
        package_guid: package_model.guid,
        droplet_hash: nil,
        sha256_checksum: nil,
        buildpack_receipt_buildpack: buildpack.name,
        buildpack_receipt_buildpack_guid: buildpack.guid,
        staging_disk_in_mb: 235,
        error_description: 'example-error',
        state: VCAP::CloudController::DropletModel::FAILED_STATE,
      )
    end
    let!(:droplet1Label) { VCAP::CloudController::DropletLabelModel.make(key_name: 'fruit', value: 'strawberry', droplet: droplet1) }
    let!(:droplet2) do
      VCAP::CloudController::DropletModel.make(
        app_guid: app_model.guid,
        created_at: Time.at(2),
        package_guid: package_model.guid,
        droplet_hash: 'my-hash',
        sha256_checksum: 'droplet-checksum-sha256',
        buildpack_receipt_buildpack: 'http://buildpack.git.url.com',
        state: VCAP::CloudController::DropletModel::STAGED_STATE,
        process_types: { 'web' => 'started' },
        execution_metadata: 'black-box-secrets',
        error_description: 'example-error',
      )
    end
    let!(:droplet2Label) { VCAP::CloudController::DropletLabelModel.make(key_name: 'seed', value: 'strawberry', droplet: droplet2) }
    let!(:droplet3) do
      VCAP::CloudController::DropletModel.make(
        app_guid: other_app_model.guid,
        created_at: Time.at(2),
        package_guid: other_package_model.guid,
        droplet_hash: 'my-hash-3',
        sha256_checksum: 'droplet-checksum-sha256-3',
        buildpack_receipt_buildpack: 'http://buildpack.git.url.com',
        state: VCAP::CloudController::DropletModel::STAGED_STATE,
        process_types: { 'web' => 'started' },
        execution_metadata: 'black-box-secrets-3',
        error_description: 'example-error',
      )
    end
    let!(:droplet3Label) { VCAP::CloudController::DropletLabelModel.make(key_name: 'fruit', value: 'mango', droplet: droplet3) }
    let(:other_package_model) do
      VCAP::CloudController::PackageModel.make(
        app_guid: other_app_model.guid,
        type: VCAP::CloudController::PackageModel::BITS_TYPE
      )
    end

    let(:per_page) { 2 }
    let(:order_by) { '-created_at' }

    before do
      droplet1.buildpack_lifecycle_data.update(buildpacks: [buildpack.name], stack: 'stack-1')
      droplet2.buildpack_lifecycle_data.update(buildpacks: ['http://buildpack.git.url.com'], stack: 'stack-2')
      droplet3.buildpack_lifecycle_data.update(buildpacks: ['http://buildpack.git.url.com'], stack: 'stack-3')
    end

    describe 'current query parameter' do
      context 'when there is a current droplet' do
        before do
          app_model.update(droplet: droplet2)
        end

        it 'returns only the droplets for the app' do
          get "/v3/apps/#{app_model.guid}/droplets", nil, developer_headers

          expect(last_response.status).to eq(200)

          returned_guids = parsed_response['resources'].map { |i| i['guid'] }
          expect(returned_guids).to match_array([droplet1.guid, droplet2.guid])
        end

        it 'returns only the droplets for the app with specified labels' do
          get "/v3/apps/#{app_model.guid}/droplets?label_selector=fruit", nil, developer_headers

          expect(last_response.status).to eq(200)

          returned_guids = parsed_response['resources'].map { |i| i['guid'] }
          expect(returned_guids).to match_array([droplet1.guid])
        end

        it 'returns only the current droplet' do
          get "/v3/apps/#{app_model.guid}/droplets?current=true", nil, developer_headers

          expect(last_response.status).to eq(200)
          expect(parsed_response['pagination']).to be_a_response_like(
            {
              'total_results' => 1,
              'total_pages' => 1,
              'first' => { 'href' => "#{link_prefix}/v3/apps/#{app_model.guid}/droplets?current=true&page=1&per_page=50" },
              'last' => { 'href' => "#{link_prefix}/v3/apps/#{app_model.guid}/droplets?current=true&page=1&per_page=50" },
              'next' => nil,
              'previous' => nil,
            })

          returned_guids = parsed_response['resources'].map { |i| i['guid'] }
          expect(returned_guids).to match_array([droplet2.guid])
        end
      end

      context 'when there is no current droplet' do
        before do
          app_model.update(droplet: nil)
        end

        it 'returns an empty list' do
          get "/v3/apps/#{app_model.guid}/droplets?current=true", nil, developer_headers

          expect(last_response.status).to eq(200)
          expect(parsed_response['pagination']).to be_a_response_like(
            {
              'total_results' => 0,
              'total_pages' => 1,
              'first' => { 'href' => "#{link_prefix}/v3/apps/#{app_model.guid}/droplets?current=true&page=1&per_page=50" },
              'last' => { 'href' => "#{link_prefix}/v3/apps/#{app_model.guid}/droplets?current=true&page=1&per_page=50" },
              'next' => nil,
              'previous' => nil,
            })

          expect(parsed_response['resources']).to match_array([])
        end
      end
    end

    it 'filters by states' do
      get "/v3/apps/#{app_model.guid}/droplets?states=STAGED", nil, developer_headers

      expect(last_response.status).to eq(200)
      expect(parsed_response['pagination']).to be_a_response_like(
        {
          'total_results' => 1,
          'total_pages' => 1,
          'first' => { 'href' => "#{link_prefix}/v3/apps/#{app_model.guid}/droplets?page=1&per_page=50&states=STAGED" },
          'last' => { 'href' => "#{link_prefix}/v3/apps/#{app_model.guid}/droplets?page=1&per_page=50&states=STAGED" },
          'next' => nil,
          'previous' => nil,
        })

      returned_guids = parsed_response['resources'].map { |i| i['guid'] }
      expect(returned_guids).to match_array([droplet2.guid])
    end

    it 'list all droplets with a buildpack lifecycle' do
      get "/v3/apps/#{app_model.guid}/droplets?order_by=#{order_by}&per_page=#{per_page}", nil, developer_headers

      expect(last_response.status).to eq(200)
      expect(parsed_response['resources']).to include(hash_including('guid' => droplet1.guid))
      expect(parsed_response['resources']).to include(hash_including('guid' => droplet2.guid))
      expect(parsed_response).to be_a_response_like({
        'pagination' => {
          'total_results' => 2,
          'total_pages' => 1,
          'first' => { 'href' => "#{link_prefix}/v3/apps/#{app_model.guid}/droplets?order_by=#{order_by}&page=1&per_page=2" },
          'last' => { 'href' => "#{link_prefix}/v3/apps/#{app_model.guid}/droplets?order_by=#{order_by}&page=1&per_page=2" },
          'next' => nil,
          'previous' => nil,
        },
        'resources' => [
          {
            'guid' => droplet2.guid,
            'state' => VCAP::CloudController::DropletModel::STAGED_STATE,
            'error' => 'example-error',
            'lifecycle' => {
              'type' => 'buildpack',
              'data' => {}
            },
            'image' => nil,
            'checksum' => { 'type' => 'sha256', 'value' => 'droplet-checksum-sha256' },
            'buildpacks' => [{ 'name' => 'http://buildpack.git.url.com', 'detect_output' => nil, 'buildpack_name' => nil, 'version' => nil }],
            'stack' => 'stack-2',
            'execution_metadata' => '[PRIVATE DATA HIDDEN IN LISTS]',
            'process_types' => { 'redacted_message' => '[PRIVATE DATA HIDDEN IN LISTS]' },
            'created_at' => iso8601,
            'updated_at' => iso8601,
            'relationships' => { 'app' => { 'data' => { 'guid' => app_model.guid } } },
            'links' => {
              'self' => { 'href' => "#{link_prefix}/v3/droplets/#{droplet2.guid}" },
              'package' => { 'href' => "#{link_prefix}/v3/packages/#{package_model.guid}" },
              'app' => { 'href' => "#{link_prefix}/v3/apps/#{app_model.guid}" },
              'assign_current_droplet' => { 'href' => "#{link_prefix}/v3/apps/#{app_model.guid}/relationships/current_droplet", 'method' => 'PATCH' },
            },
            'metadata' => {
              'labels' => {
                'seed' => 'strawberry'
              },
              'annotations' => {}
            },
          },
          {
            'guid' => droplet1.guid,
            'state' => VCAP::CloudController::DropletModel::FAILED_STATE,
            'error' => 'example-error',
            'lifecycle' => {
              'type' => 'buildpack',
              'data' => {}
            },
            'image' => nil,
            'checksum' => nil,
            'buildpacks' => [{ 'name' => buildpack.name, 'detect_output' => nil, 'buildpack_name' => nil, 'version' => nil }],
            'stack' => 'stack-1',
            'execution_metadata' => '[PRIVATE DATA HIDDEN IN LISTS]',
            'process_types' => { 'redacted_message' => '[PRIVATE DATA HIDDEN IN LISTS]' },
            'created_at' => iso8601,
            'updated_at' => iso8601,
            'relationships' => { 'app' => { 'data' => { 'guid' => app_model.guid } } },
            'links' => {
              'self' => { 'href' => "#{link_prefix}/v3/droplets/#{droplet1.guid}" },
              'package' => { 'href' => "#{link_prefix}/v3/packages/#{package_model.guid}" },
              'app' => { 'href' => "#{link_prefix}/v3/apps/#{app_model.guid}" },
              'assign_current_droplet' => { 'href' => "#{link_prefix}/v3/apps/#{app_model.guid}/relationships/current_droplet", 'method' => 'PATCH' },
            },
            'metadata' => {
              'labels' => {
                'fruit' => 'strawberry',
              },
              'annotations' => {}
            },
          }
        ]
      })
    end
  end

  describe 'GET /v3/packages/:guid/droplets' do
    let(:buildpack) { VCAP::CloudController::Buildpack.make }
    let(:package_model) do
      VCAP::CloudController::PackageModel.make(
        app_guid: app_model.guid,
        type: VCAP::CloudController::PackageModel::BITS_TYPE
      )
    end
    let(:other_package_model) do
      VCAP::CloudController::PackageModel.make(
        app_guid: other_app_model.guid,
        type: VCAP::CloudController::PackageModel::BITS_TYPE
      )
    end

    let!(:droplet1) do
      VCAP::CloudController::DropletModel.make(
        app_guid: app_model.guid,
        created_at: Time.at(1),
        package_guid: package_model.guid,
        droplet_hash: nil,
        sha256_checksum: nil,
        buildpack_receipt_buildpack: buildpack.name,
        buildpack_receipt_buildpack_guid: buildpack.guid,
        error_description: 'example-error',
        state: VCAP::CloudController::DropletModel::FAILED_STATE,
      )
    end

    let!(:droplet2) do
      VCAP::CloudController::DropletModel.make(
        app_guid: app_model.guid,
        created_at: Time.at(2),
        package_guid: package_model.guid,
        droplet_hash: 'my-hash',
        sha256_checksum: 'droplet-checksum-sha256',
        buildpack_receipt_buildpack: 'http://buildpack.git.url.com',
        state: VCAP::CloudController::DropletModel::STAGED_STATE,
        process_types: { 'web' => 'started' },
        execution_metadata: 'black-box-secrets',
        error_description: 'example-error'
      )
    end

    let!(:droplet3) do
      VCAP::CloudController::DropletModel.make(
        app_guid: other_app_model.guid,
        created_at: Time.at(2),
        package_guid: other_package_model.guid,
        droplet_hash: 'my-hash-3',
        sha256_checksum: 'droplet-checksum-sha256-3',
        buildpack_receipt_buildpack: 'http://buildpack.git.url.com',
        state: VCAP::CloudController::DropletModel::STAGED_STATE,
        process_types: { 'web' => 'started' },
        execution_metadata: 'black-box-secrets-3',
        error_description: 'example-error',
      )
    end
    let!(:droplet1Label) { VCAP::CloudController::DropletLabelModel.make(key_name: 'fruit', value: 'strawberry', droplet: droplet1) }
    let!(:droplet2Label) { VCAP::CloudController::DropletLabelModel.make(key_name: 'limes', value: 'horse', droplet: droplet2) }
    let!(:droplet3Label) { VCAP::CloudController::DropletLabelModel.make(key_name: 'fruit', value: 'strawberry', droplet: droplet3) }

    let(:per_page) { 2 }
    let(:order_by) { '-created_at' }

    before do
      droplet1.buildpack_lifecycle_data.update(buildpacks: [buildpack.name], stack: 'stack-1')
      droplet2.buildpack_lifecycle_data.update(buildpacks: ['http://buildpack.git.url.com'], stack: 'stack-2')
    end

    it 'returns only the droplets for the package' do
      get "/v3/packages/#{package_model.guid}/droplets", nil, developer_headers

      expect(last_response.status).to eq(200)

      returned_guids = parsed_response['resources'].map { |i| i['guid'] }
      expect(returned_guids).to match_array([droplet1.guid, droplet2.guid])
    end

    it 'returns only the packages for the app with specified labels' do
      get "/v3/packages/#{package_model.guid}/droplets?label_selector=fruit", nil, developer_headers

      expect(last_response.status).to eq(200)

      returned_guids = parsed_response['resources'].map { |i| i['guid'] }
      expect(returned_guids).to match_array([droplet1.guid])
    end

    it 'filters by states' do
      get "/v3/packages/#{package_model.guid}/droplets?states=STAGED", nil, developer_headers

      expect(last_response.status).to eq(200)
      expect(parsed_response['pagination']).to be_a_response_like(
        {
          'total_results' => 1,
          'total_pages' => 1,
          'first' => { 'href' => "#{link_prefix}/v3/packages/#{package_model.guid}/droplets?page=1&per_page=50&states=STAGED" },
          'last' => { 'href' => "#{link_prefix}/v3/packages/#{package_model.guid}/droplets?page=1&per_page=50&states=STAGED" },
          'next' => nil,
          'previous' => nil,
        })

      returned_guids = parsed_response['resources'].map { |i| i['guid'] }
      expect(returned_guids).to match_array([droplet2.guid])
    end

    it 'list all droplets with a buildpack lifecycle' do
      get "/v3/packages/#{package_model.guid}/droplets?order_by=#{order_by}&per_page=#{per_page}", nil, developer_headers

      expect(last_response.status).to eq(200)
      expect(parsed_response['resources']).to include(hash_including('guid' => droplet1.guid))
      expect(parsed_response['resources']).to include(hash_including('guid' => droplet2.guid))
      expect(parsed_response).to be_a_response_like({
        'pagination' => {
          'total_results' => 2,
          'total_pages' => 1,
          'first' => { 'href' => "#{link_prefix}/v3/packages/#{package_model.guid}/droplets?order_by=#{order_by}&page=1&per_page=2" },
          'last' => { 'href' => "#{link_prefix}/v3/packages/#{package_model.guid}/droplets?order_by=#{order_by}&page=1&per_page=2" },
          'next' => nil,
          'previous' => nil,
        },
        'resources' => [
          {
            'guid' => droplet2.guid,
            'state' => VCAP::CloudController::DropletModel::STAGED_STATE,
            'error' => 'example-error',
            'lifecycle' => {
              'type' => 'buildpack',
              'data' => {}
            },
            'image' => nil,
            'checksum' => { 'type' => 'sha256', 'value' => 'droplet-checksum-sha256' },
            'buildpacks' => [{ 'name' => 'http://buildpack.git.url.com', 'detect_output' => nil, 'buildpack_name' => nil, 'version' => nil }],
            'stack' => 'stack-2',
            'execution_metadata' => '[PRIVATE DATA HIDDEN IN LISTS]',
            'process_types' => { 'redacted_message' => '[PRIVATE DATA HIDDEN IN LISTS]' },
            'created_at' => iso8601,
            'updated_at' => iso8601,
            'relationships' => { 'app' => { 'data' => { 'guid' => app_model.guid } } },
            'links' => {
              'self' => { 'href' => "#{link_prefix}/v3/droplets/#{droplet2.guid}" },
              'package' => { 'href' => "#{link_prefix}/v3/packages/#{package_model.guid}" },
              'app' => { 'href' => "#{link_prefix}/v3/apps/#{app_model.guid}" },
              'assign_current_droplet' => { 'href' => "#{link_prefix}/v3/apps/#{app_model.guid}/relationships/current_droplet", 'method' => 'PATCH' },
            },
            'metadata' => {
              'labels' => {
                'limes' => 'horse'
              },
              'annotations' => {}
            },
          },
          {
            'guid' => droplet1.guid,
            'state' => VCAP::CloudController::DropletModel::FAILED_STATE,
            'error' => 'example-error',
            'lifecycle' => {
              'type' => 'buildpack',
              'data' => {}
            },
            'image' => nil,
            'checksum' => nil,
            'buildpacks' => [{ 'name' => buildpack.name, 'detect_output' => nil, 'buildpack_name' => nil, 'version' => nil }],
            'stack' => 'stack-1',
            'execution_metadata' => '[PRIVATE DATA HIDDEN IN LISTS]',
            'process_types' => { 'redacted_message' => '[PRIVATE DATA HIDDEN IN LISTS]' },
            'created_at' => iso8601,
            'updated_at' => iso8601,
            'relationships' => { 'app' => { 'data' => { 'guid' => app_model.guid } } },
            'links' => {
              'self' => { 'href' => "#{link_prefix}/v3/droplets/#{droplet1.guid}" },
              'package' => { 'href' => "#{link_prefix}/v3/packages/#{package_model.guid}" },
              'app' => { 'href' => "#{link_prefix}/v3/apps/#{app_model.guid}" },
              'assign_current_droplet' => { 'href' => "#{link_prefix}/v3/apps/#{app_model.guid}/relationships/current_droplet", 'method' => 'PATCH' },
            },
            'metadata' => {
              'labels' => {
                'fruit' => 'strawberry'
              },
              'annotations' => {}
            },
          }
        ]
      })
    end
  end

  describe 'POST /v3/droplets/:guid/copy' do
    let(:new_app) { VCAP::CloudController::AppModel.make(space_guid: space.guid) }
    let(:package_model) { VCAP::CloudController::PackageModel.make(app_guid: app_model.guid) }
    let!(:og_droplet) do
      VCAP::CloudController::DropletModel.make(
        state: VCAP::CloudController::DropletModel::STAGED_STATE,
        app_guid: app_model.guid,
        package_guid: package_model.guid,
        buildpack_receipt_buildpack: 'http://buildpack.git.url.com',
        error_description: nil,
        execution_metadata: 'some-data',
        droplet_hash: 'shalalala',
        sha256_checksum: 'droplet-checksum-sha256',
        process_types: { 'web' => 'start-command' },
      )
    end
    let(:app_guid) { droplet_model.app_guid }
    let(:copy_request_json) do
      {
        relationships: {
          app: { data: { guid: new_app.guid } }
        }
      }.to_json
    end
    before do
      og_droplet.buildpack_lifecycle_data.update(buildpacks: ['http://buildpack.git.url.com'], stack: 'stack-name')
    end

    it 'copies a droplet' do
      post "/v3/droplets?source_guid=#{og_droplet.guid}", copy_request_json, developer_headers

      parsed_response = MultiJson.load(last_response.body)
      copied_droplet = VCAP::CloudController::DropletModel.last

      expect(last_response.status).to eq(201), "Expected 201, got status: #{last_response.status} with body: #{parsed_response}"
      expect(parsed_response).to be_a_response_like({
        'guid' => copied_droplet.guid,
        'state' => VCAP::CloudController::DropletModel::COPYING_STATE,
        'error' => nil,
        'lifecycle' => {
          'type' => 'buildpack',
          'data' => {}
        },
        'checksum' => nil,
        'buildpacks' => [{ 'name' => 'http://buildpack.git.url.com', 'detect_output' => nil, 'buildpack_name' => nil, 'version' => nil }],
        'stack' => 'stack-name',
        'execution_metadata' => 'some-data',
        'image' => nil,
        'process_types' => { 'web' => 'start-command' },
        'created_at' => iso8601,
        'updated_at' => iso8601,
        'relationships' => { 'app' => { 'data' => { 'guid' => new_app.guid } } },
        'links' => {
          'self' => { 'href' => "#{link_prefix}/v3/droplets/#{copied_droplet.guid}" },
          'app' => { 'href' => "#{link_prefix}/v3/apps/#{new_app.guid}" },
          'assign_current_droplet' => { 'href' => "#{link_prefix}/v3/apps/#{new_app.guid}/relationships/current_droplet", 'method' => 'PATCH' },
        },
        'metadata' => {
          'labels' => {},
          'annotations' => {}
        },
      })
    end
  end

  describe 'POST /v3/droplets/:guid/upload' do
    let(:droplet) do
      VCAP::CloudController::DropletModel.make(
        app: app_model,
        state: VCAP::CloudController::DropletModel::AWAITING_UPLOAD_STATE
      )
    end

    let(:api_call) { lambda { |user_headers| post "/v3/droplets/#{droplet.guid}/upload", params.to_json, user_headers } }

    let(:params) do
      { bits_name: 'my-droplet.tgz', bits_path: '/tmp/uploads/my-droplet.tgz' }
    end

    let(:droplet_json) do
      {
        guid: UUID_REGEX,
        state: 'PROCESSING_UPLOAD',
        error: nil,
        lifecycle: {
          type: 'buildpack',
          data: {}
        },
        execution_metadata: droplet.execution_metadata,
        process_types: droplet.process_types,
        checksum: {
          type: 'sha256',
          value: droplet.sha256_checksum
        },
        buildpacks: [],
        stack: droplet.buildpack_lifecycle_data.stack,
        image: nil,
        created_at: iso8601,
        updated_at: iso8601,
        relationships: { app: { data: { guid: app_model.guid } } },
        metadata: {
          labels: {},
          annotations: {}
        },
        links: {
          self: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/droplets\/#{droplet.guid}) },
          app: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/apps\/#{UUID_REGEX}) },
          assign_current_droplet: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/apps\/#{UUID_REGEX}\/relationships\/current_droplet), method: 'PATCH' },
        }
      }
    end

    let(:expected_codes_and_responses) do
      h = Hash.new(
        code: 403,
      )
      h['admin'] = {
        code: 202,
        response_object: droplet_json
      }
      h['space_developer'] = {
        code: 202,
        response_object: droplet_json
      }
      h.freeze
    end

    before do
      # VCAP::CloudController::DropletUploadMessage validations will try to
      # stat the file, which in this case would fail since this file doesn't
      # exist. In order to be able to run validations we stub File.stat so that
      # the size check always passes.
      allow(File).to receive(:stat).and_return(instance_double(File::Stat, size: 12))
    end

    it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS do
      let(:expected_event_hash) do
        {
          type: 'audit.app.droplet.upload',
          actee: app_model.guid,
          actee_type: 'app',
          actee_name: app_model.name,
          metadata: { droplet_guid: parsed_response['guid'] }.to_json,
          space_guid: space.guid,
          organization_guid: org.guid,
        }
      end
    end

    it 'enqueues a processing job' do
      post "/v3/droplets/#{droplet.guid}/upload", params.to_json, developer_headers

      expect(last_response.status).to eq(202)

      get last_response.headers['Location'], nil, admin_headers

      expect(last_response.status).to eq(200)
    end

    context 'when the droplet is not found' do
      it 'returns 404 with a helpful error message' do
        post '/v3/droplets/bad-droplet-guid/upload', params.to_json, developer_headers

        expect(last_response.status).to eq(404)
        expect(last_response).to have_error_message("Droplet with guid 'bad-droplet-guid' does not exist, or you do not have access to it.")
      end
    end

    context 'when the droplet is not AWAITING_UPLOAD' do
      let(:staged_droplet) do
        VCAP::CloudController::DropletModel.make(
          app: app_model,
          state: VCAP::CloudController::DropletModel::STAGED_STATE
        )
      end

      it 'returns 422 with a helpful error message' do
        post "/v3/droplets/#{staged_droplet.guid}/upload", params.to_json, developer_headers

        expect(last_response.status).to eq(422)
        expect(last_response).to have_error_message('Droplet may be uploaded only once. Create a new droplet to upload bits.')
      end
    end

    context 'when the bits are not called "bits"' do
      let(:invalid_params) do
        { bots_name: 'bots.tgz', bots_path: '/tmp/uploads/bots.tgz' }
      end

      it 'returns 422 with a helpful error message' do
        post "/v3/droplets/#{droplet.guid}/upload", invalid_params.to_json, developer_headers

        expect(last_response.status).to eq(422)
        expect(last_response).to have_error_message(/Uploaded droplet file is invalid:.* A droplet tgz file must be uploaded as 'bits'/)
      end
    end
  end

  describe 'PATCH v3/droplets/:guid' do
    let(:package_model) { VCAP::CloudController::PackageModel.make(app_guid: app_model.guid) }
    let!(:og_droplet) do
      VCAP::CloudController::DropletModel.make(
        state: VCAP::CloudController::DropletModel::STAGED_STATE,
        app_guid: app_model.guid,
        package_guid: package_model.guid,
        buildpack_receipt_buildpack: 'http://buildpack.git.url.com',
        error_description: nil,
        execution_metadata: 'some-data',
        droplet_hash: 'shalalala',
        sha256_checksum: 'droplet-checksum-sha256',
        process_types: { 'web' => 'start-command' },
      )
    end
    let(:update_request) do
      {
        metadata: {
          labels: {
            'release' => 'stable',
            'code.cloudfoundry.org/cloud_controller_ng' => 'awesome',
            'delete-me' => nil,
          },
          annotations: {
            'potato' => 'sieglinde',
            'key' => ''
          }
        }
      }
    end

    before do
      og_droplet.buildpack_lifecycle_data.update(buildpacks: ['http://buildpack.git.url.com'], stack: 'stack-name')
    end

    it 'updates the metadata on a droplet' do
      patch "/v3/droplets/#{og_droplet.guid}", update_request.to_json, developer_headers
      expect(last_response.status).to eq(200), last_response.body

      og_droplet.reload
      parsed_response = MultiJson.load(last_response.body)
      expect(parsed_response['metadata']).to eq(
        'labels' => {
          'release' => 'stable',
          'code.cloudfoundry.org/cloud_controller_ng' => 'awesome'
        },
        'annotations' => {
          'potato' => 'sieglinde',
          'key' => ''
        }
      )
    end
  end
end
