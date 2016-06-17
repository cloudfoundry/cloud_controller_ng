require 'spec_helper'

RSpec.describe 'Droplets' do
  let(:space) { VCAP::CloudController::Space.make }
  let(:app_model) { VCAP::CloudController::AppModel.make(space_guid: space.guid, name: 'my-app') }
  let(:developer) { make_developer_for_space(space) }
  let(:developer_headers) { headers_for(developer) }

  let(:parsed_response) { MultiJson.load(last_response.body) }

  describe 'POST /v3/packages/:guid/droplets' do
    let(:diego_staging_response) do
      {
        execution_metadata:     'String',
        detected_start_command: {},
        lifecycle_data:         {
          buildpack_key:      'String',
          detected_buildpack: 'String',
        }
      }
    end
    let!(:package) do
      VCAP::CloudController::PackageModel.make(
        app_guid: app_model.guid,
        state:    VCAP::CloudController::PackageModel::READY_STATE,
        type:     VCAP::CloudController::PackageModel::BITS_TYPE,
        url:      'hello.com'
      )
    end

    let(:create_request) do
      {
        environment_variables: { 'CUSTOMENV' => 'env value' },
        staging_memory_in_mb:  1024,
        staging_disk_in_mb:    4096,
        lifecycle:             {
          type: 'buildpack',
          data: {
            stack:     'cflinuxfs2',
            buildpack: 'http://github.com/myorg/awesome-buildpack'
          }
        },
      }
    end

    before do
      allow_any_instance_of(CloudController::Blobstore::UrlGenerator).to receive(:v3_app_buildpack_cache_download_url).and_return('some-string')
      allow_any_instance_of(CloudController::Blobstore::UrlGenerator).to receive(:v3_app_buildpack_cache_upload_url).and_return('some-string')
      allow_any_instance_of(CloudController::Blobstore::UrlGenerator).to receive(:package_download_url).and_return('some-string')
      allow_any_instance_of(CloudController::Blobstore::UrlGenerator).to receive(:package_droplet_upload_url).and_return('some-string')
      stub_request(:put, "#{TestConfig.config[:diego_stager_url]}/v1/staging/whatuuid").
        to_return(status: 202, body: diego_staging_response.to_json)
      stub_const('SecureRandom', double(:sr, uuid: 'whatuuid', hex: '8-octetx'))
    end

    it 'creates a droplet' do
      post "/v3/packages/#{package.guid}/droplets", create_request.to_json, json_headers(developer_headers)

      created_droplet = VCAP::CloudController::DropletModel.last

      expected_response = {
        'guid'                  => created_droplet.guid,
        'state'                 => 'PENDING',
        'error'                 => nil,
        'lifecycle'             => {
          'type' => 'buildpack',
          'data' => {
            'stack'     => 'cflinuxfs2',
            'buildpack' => 'http://github.com/myorg/awesome-buildpack'
          }
        },
        'environment_variables' => {
          'CF_STACK'         => 'cflinuxfs2',
          'CUSTOMENV'        => 'env value',
          'MEMORY_LIMIT'     => '1024m',
          'VCAP_SERVICES'    => {},
          'VCAP_APPLICATION' => {
            'limits'              => { 'mem' => 1024, 'disk' => 4096, 'fds' => 16384 },
            'application_id'      => app_model.guid,
            'application_version' => 'whatuuid',
            'application_name'    => app_model.name, 'application_uris' => [],
            'version'             => 'whatuuid',
            'name'                => app_model.name,
            'space_name'          => space.name,
            'space_id'            => space.guid,
            'uris'                => [],
            'users'               => nil
          }
        },
        'staging_memory_in_mb'  => 1024,
        'staging_disk_in_mb'    => 4096,
        'result'                => nil,
        'created_at'            => iso8601,
        'updated_at'            => nil,
        'links'                 => {
          'self'                   => { 'href' => "/v3/droplets/#{created_droplet.guid}" },
          'package'                => { 'href' => "/v3/packages/#{package.guid}" },
          'app'                    => { 'href' => "/v3/apps/#{app_model.guid}" },
          'assign_current_droplet' => { 'href' => "/v3/apps/#{app_model.guid}/droplets/current", 'method' => 'PUT' },
        }
      }

      expect(last_response.status).to eq(201)
      expect(parsed_response).to be_a_response_like(expected_response)

      event = VCAP::CloudController::Event.last
      expect(event.values).to include(
        type:              'audit.app.droplet.create',
        actee:             app_model.guid,
        actee_type:        'v3-app',
        actee_name:        'my-app',
        actor:             developer.guid,
        actor_type:        'user',
        space_guid:        space.guid,
        organization_guid: space.organization.guid,
      )
    end
  end

  describe 'GET /v3/droplets/:guid' do
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
    end

    it 'gets a droplet' do
      get "/v3/droplets/#{droplet_model.guid}", nil, developer_headers

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
        'staging_memory_in_mb'  => 100,
        'staging_disk_in_mb'    => 200,
        'result'                => {
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

    it 'redacts information for auditors' do
      auditor = VCAP::CloudController::User.make
      space.organization.add_user(auditor)
      space.add_auditor(auditor)

      get "/v3/droplets/#{droplet_model.guid}", nil, headers_for(auditor)

      parsed_response = MultiJson.load(last_response.body)

      expect(last_response.status).to eq(200)
      expect(parsed_response['environment_variables']).to eq({ 'redacted_message' => '[PRIVATE DATA HIDDEN]' })
      expect(parsed_response['result']['process_types']).to eq({ 'redacted_message' => '[PRIVATE DATA HIDDEN]' })
      expect(parsed_response['result']['execution_metadata']).to eq('[PRIVATE DATA HIDDEN]')
    end
  end

  describe 'GET /v3/droplets' do
    let(:buildpack) { VCAP::CloudController::Buildpack.make }
    let(:package_model) do
      VCAP::CloudController::PackageModel.make(
        app_guid: app_model.guid,
        type:     VCAP::CloudController::PackageModel::BITS_TYPE
      )
    end

    let!(:droplet1) do
      VCAP::CloudController::DropletModel.make(
        app_guid:                         app_model.guid,
        created_at:                       Time.at(1),
        package_guid:                     package_model.guid,
        buildpack_receipt_buildpack:      buildpack.name,
        buildpack_receipt_buildpack_guid: buildpack.guid,
        buildpack_receipt_stack_name:     'stack-1',
        environment_variables:            { 'yuu' => 'huuu' },
        staging_disk_in_mb:               235,
        error:                            'example-error'
      )
    end
    let!(:droplet2) do
      VCAP::CloudController::DropletModel.make(
        app_guid:                     app_model.guid,
        created_at:                   Time.at(2),
        package_guid:                 package_model.guid,
        droplet_hash:                 'my-hash',
        buildpack_receipt_buildpack:  'http://buildpack.git.url.com',
        buildpack_receipt_stack_name: 'stack-2',
        state:                        VCAP::CloudController::DropletModel::STAGED_STATE,
        process_types:                { 'web' => 'started' },
        staging_memory_in_mb:         123,
        staging_disk_in_mb:           456,
        execution_metadata:           'black-box-secrets',
        error:                        'example-error'
      )
    end

    let(:per_page) { 2 }
    let(:order_by) { '-created_at' }

    before do
      droplet1.buildpack_lifecycle_data.update(buildpack: buildpack.name, stack: 'stack-1')
      droplet2.buildpack_lifecycle_data.update(buildpack: 'http://buildpack.git.url.com', stack: 'stack-2')
    end

    it 'list all droplets with a buildpack lifecycle' do
      get "/v3/droplets?order_by=#{order_by}&per_page=#{per_page}", nil, developer_headers
      expect(last_response.status).to eq(200)
      expect(parsed_response['resources']).to include(hash_including('guid' => droplet1.guid))
      expect(parsed_response['resources']).to include(hash_including('guid' => droplet2.guid))
      expect(parsed_response).to be_a_response_like({
        'pagination' => {
          'total_results' => 2,
          'total_pages'   => 1,
          'first'         => { 'href' => "/v3/droplets?order_by=#{order_by}&page=1&per_page=2" },
          'last'          => { 'href' => "/v3/droplets?order_by=#{order_by}&page=1&per_page=2" },
          'next'          => nil,
          'previous'      => nil,
        },
        'resources' => [
          {
            'guid'                  => droplet2.guid,
            'state'                 => VCAP::CloudController::DropletModel::STAGED_STATE,
            'error'                 => 'example-error',
            'lifecycle'             => {
              'type' => 'buildpack',
              'data' => {
                'buildpack' => 'http://buildpack.git.url.com',
                'stack'     => 'stack-2'
              }
            },
            'staging_memory_in_mb'  => 123,
            'staging_disk_in_mb'    => 456,
            'result'                => {
              'hash'                   => { 'type' => 'sha1', 'value' => 'my-hash' },
              'buildpack'              => 'http://buildpack.git.url.com',
              'stack'                  => 'stack-2',
              'execution_metadata'     => '[PRIVATE DATA HIDDEN IN LISTS]',
              'process_types'          => { 'redacted_message' => '[PRIVATE DATA HIDDEN IN LISTS]' }
            },
            'environment_variables' => { 'redacted_message' => '[PRIVATE DATA HIDDEN IN LISTS]' },
            'created_at'            => iso8601,
            'updated_at'            => iso8601,
            'links'                 => {
              'self'                   => { 'href' => "/v3/droplets/#{droplet2.guid}" },
              'package'                => { 'href' => "/v3/packages/#{package_model.guid}" },
              'app'                    => { 'href' => "/v3/apps/#{app_model.guid}" },
              'assign_current_droplet' => { 'href' => "/v3/apps/#{app_model.guid}/droplets/current", 'method' => 'PUT' },
            }
          },
          {
            'guid'                  => droplet1.guid,
            'state'                 => VCAP::CloudController::DropletModel::STAGING_STATE,
            'error'                 => 'example-error',
            'lifecycle'             => {
              'type' => 'buildpack',
              'data' => {
                'buildpack' => buildpack.name,
                'stack'     => 'stack-1'
              }
            },
            'staging_memory_in_mb'  => 123,
            'staging_disk_in_mb'    => 235,
            'result'                => nil,
            'environment_variables' => { 'redacted_message' => '[PRIVATE DATA HIDDEN IN LISTS]' },
            'created_at'            => iso8601,
            'updated_at'            => iso8601,
            'links'                 => {
              'self'                   => { 'href' => "/v3/droplets/#{droplet1.guid}" },
              'package'                => { 'href' => "/v3/packages/#{package_model.guid}" },
              'app'                    => { 'href' => "/v3/apps/#{app_model.guid}" },
              'assign_current_droplet' => { 'href' => "/v3/apps/#{app_model.guid}/droplets/current", 'method' => 'PUT' },
              'buildpack'              => { 'href' => "/v2/buildpacks/#{buildpack.guid}" }
            }
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
      let!(:droplet3) { VCAP::CloudController::DropletModel.make(app: app_model2, state: VCAP::CloudController::DropletModel::PENDING_STATE) }
      let!(:droplet4) { VCAP::CloudController::DropletModel.make(app: app_model3, state: VCAP::CloudController::DropletModel::PENDING_STATE) }

      it 'filters by states' do
        get '/v3/droplets?states=STAGED,PENDING', nil, developer_headers

        expect(last_response.status).to eq(200)
        expect(parsed_response['pagination']).to be_a_response_like(
          {
            'total_results' => 2,
            'total_pages'   => 1,
            'first'         => { 'href' => '/v3/droplets?page=1&per_page=50&states=STAGED%2CPENDING' },
            'last'          => { 'href' => '/v3/droplets?page=1&per_page=50&states=STAGED%2CPENDING' },
            'next'          => nil,
            'previous'      => nil,
          })

        returned_guids = parsed_response['resources'].map { |i| i['guid'] }
        expect(returned_guids).to match_array([droplet2.guid, droplet3.guid])
      end

      it 'filters by app_guids' do
        get "/v3/droplets?app_guids=#{app_model.guid}", nil, developer_headers

        expect(last_response.status).to eq(200)
        expect(parsed_response['pagination']).to be_a_response_like(
          {
            'total_results' => 2,
            'total_pages'   => 1,
            'first'         => { 'href' => "/v3/droplets?app_guids=#{app_model.guid}&page=1&per_page=50" },
            'last'          => { 'href' => "/v3/droplets?app_guids=#{app_model.guid}&page=1&per_page=50" },
            'next'          => nil,
            'previous'      => nil,
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
            'total_pages'   => 1,
            'first'         => { 'href' => "/v3/droplets?guids=#{droplet1.guid}%2C#{droplet3.guid}&page=1&per_page=50" },
            'last'          => { 'href' => "/v3/droplets?guids=#{droplet1.guid}%2C#{droplet3.guid}&page=1&per_page=50" },
            'next'          => nil,
            'previous'      => nil,
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
            'total_pages'   => 1,
            'first'         => { 'href' => "/v3/droplets?organization_guids=#{organization1.guid}&page=1&per_page=50" },
            'last'          => { 'href' => "/v3/droplets?organization_guids=#{organization1.guid}&page=1&per_page=50" },
            'next'          => nil,
            'previous'      => nil,
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
            'total_pages'   => 1,
            'first'         => { 'href' => "/v3/droplets?page=1&per_page=50&space_guids=#{space.guid}%2C#{space2.guid}" },
            'last'          => { 'href' => "/v3/droplets?page=1&per_page=50&space_guids=#{space.guid}%2C#{space2.guid}" },
            'next'          => nil,
            'previous'      => nil,
          })

        returned_guids = parsed_response['resources'].map { |i| i['guid'] }
        expect(returned_guids).to match_array([droplet1.guid, droplet2.guid, droplet3.guid])
      end
    end
  end

  describe 'DELETE /v3/droplets/:guid' do
    let!(:droplet) { VCAP::CloudController::DropletModel.make(:buildpack, app_guid: app_model.guid) }

    it 'deletes a droplet' do
      expect {
        delete "/v3/droplets/#{droplet.guid}", nil, developer_headers
      }.to change { VCAP::CloudController::DropletModel.count }.by(-1)
      expect(last_response.status).to eq(204)
      expect(VCAP::CloudController::DropletModel.find(guid: droplet.guid)).to be_nil
    end
  end

  describe 'GET /v3/apps/:guid/droplets' do
    let(:buildpack) { VCAP::CloudController::Buildpack.make }
    let(:package_model) do
      VCAP::CloudController::PackageModel.make(
        app_guid: app_model.guid,
        type:     VCAP::CloudController::PackageModel::BITS_TYPE
      )
    end

    let!(:droplet1) do
      VCAP::CloudController::DropletModel.make(
        app_guid:                         app_model.guid,
        created_at:                       Time.at(1),
        package_guid:                     package_model.guid,
        buildpack_receipt_buildpack:      buildpack.name,
        buildpack_receipt_buildpack_guid: buildpack.guid,
        buildpack_receipt_stack_name:     'stack-1',
        environment_variables:            { 'yuu' => 'huuu' },
        staging_disk_in_mb:               235,
        error:                            'example-error',
        state:                            VCAP::CloudController::DropletModel::PENDING_STATE,
      )
    end
    let!(:droplet2) do
      VCAP::CloudController::DropletModel.make(
        app_guid:                     app_model.guid,
        created_at:                   Time.at(2),
        package_guid:                 package_model.guid,
        droplet_hash:                 'my-hash',
        buildpack_receipt_buildpack:  'http://buildpack.git.url.com',
        buildpack_receipt_stack_name: 'stack-2',
        state:                        VCAP::CloudController::DropletModel::STAGED_STATE,
        process_types:                { 'web' => 'started' },
        staging_memory_in_mb:         123,
        staging_disk_in_mb:           456,
        execution_metadata:           'black-box-secrets',
        error:                        'example-error'
      )
    end

    let(:per_page) { 2 }
    let(:order_by) { '-created_at' }

    before do
      droplet1.buildpack_lifecycle_data.update(buildpack: buildpack.name, stack: 'stack-1')
      droplet2.buildpack_lifecycle_data.update(buildpack: 'http://buildpack.git.url.com', stack: 'stack-2')
    end

    it 'filters by states' do
      get "/v3/apps/#{app_model.guid}/droplets?states=STAGED", nil, developer_headers

      expect(last_response.status).to eq(200)
      expect(parsed_response['pagination']).to be_a_response_like(
        {
          'total_results' => 1,
          'total_pages'   => 1,
          'first'         => { 'href' => "/v3/apps/#{app_model.guid}/droplets?page=1&per_page=50&states=STAGED" },
          'last'          => { 'href' => "/v3/apps/#{app_model.guid}/droplets?page=1&per_page=50&states=STAGED" },
          'next'          => nil,
          'previous'      => nil,
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
          'total_pages'   => 1,
          'first'         => { 'href' => "/v3/apps/#{app_model.guid}/droplets?order_by=#{order_by}&page=1&per_page=2" },
          'last'          => { 'href' => "/v3/apps/#{app_model.guid}/droplets?order_by=#{order_by}&page=1&per_page=2" },
          'next'          => nil,
          'previous'      => nil,
        },
        'resources' => [
          {
            'guid'                  => droplet2.guid,
            'state'                 => VCAP::CloudController::DropletModel::STAGED_STATE,
            'error'                 => 'example-error',
            'lifecycle'             => {
              'type' => 'buildpack',
              'data' => {
                'buildpack' => 'http://buildpack.git.url.com',
                'stack'     => 'stack-2'
              }
            },
            'staging_memory_in_mb'  => 123,
            'staging_disk_in_mb'    => 456,
            'result'                => {
              'hash'                   => { 'type' => 'sha1', 'value' => 'my-hash' },
              'buildpack'              => 'http://buildpack.git.url.com',
              'stack'                  => 'stack-2',
              'execution_metadata'     => '[PRIVATE DATA HIDDEN IN LISTS]',
              'process_types'          => { 'redacted_message' => '[PRIVATE DATA HIDDEN IN LISTS]' }
            },
            'environment_variables' => { 'redacted_message' => '[PRIVATE DATA HIDDEN IN LISTS]' },
            'created_at'            => iso8601,
            'updated_at'            => iso8601,
            'links'                 => {
              'self'                   => { 'href' => "/v3/droplets/#{droplet2.guid}" },
              'package'                => { 'href' => "/v3/packages/#{package_model.guid}" },
              'app'                    => { 'href' => "/v3/apps/#{app_model.guid}" },
              'assign_current_droplet' => { 'href' => "/v3/apps/#{app_model.guid}/droplets/current", 'method' => 'PUT' },
            }
          },
          {
            'guid'                  => droplet1.guid,
            'state'                 => VCAP::CloudController::DropletModel::PENDING_STATE,
            'error'                 => 'example-error',
            'lifecycle'             => {
              'type' => 'buildpack',
              'data' => {
                'buildpack' => buildpack.name,
                'stack'     => 'stack-1'
              }
            },
            'staging_memory_in_mb'  => 123,
            'staging_disk_in_mb'    => 235,
            'result'                => nil,
            'environment_variables' => { 'redacted_message' => '[PRIVATE DATA HIDDEN IN LISTS]' },
            'created_at'            => iso8601,
            'updated_at'            => iso8601,
            'links'                 => {
              'self'                   => { 'href' => "/v3/droplets/#{droplet1.guid}" },
              'package'                => { 'href' => "/v3/packages/#{package_model.guid}" },
              'app'                    => { 'href' => "/v3/apps/#{app_model.guid}" },
              'assign_current_droplet' => { 'href' => "/v3/apps/#{app_model.guid}/droplets/current", 'method' => 'PUT' },
              'buildpack'              => { 'href' => "/v2/buildpacks/#{buildpack.guid}" }
            }
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
        type:     VCAP::CloudController::PackageModel::BITS_TYPE
      )
    end

    let!(:droplet1) do
      VCAP::CloudController::DropletModel.make(
        app_guid:                         app_model.guid,
        created_at:                       Time.at(1),
        package_guid:                     package_model.guid,
        buildpack_receipt_buildpack:      buildpack.name,
        buildpack_receipt_buildpack_guid: buildpack.guid,
        buildpack_receipt_stack_name:     'stack-1',
        environment_variables:            { 'yuu' => 'huuu' },
        staging_disk_in_mb:               235,
        error:                            'example-error',
        state:                            VCAP::CloudController::DropletModel::PENDING_STATE,
      )
    end

    let!(:droplet2) do
      VCAP::CloudController::DropletModel.make(
        app_guid:                     app_model.guid,
        created_at:                   Time.at(2),
        package_guid:                 package_model.guid,
        droplet_hash:                 'my-hash',
        buildpack_receipt_buildpack:  'http://buildpack.git.url.com',
        buildpack_receipt_stack_name: 'stack-2',
        state:                        VCAP::CloudController::DropletModel::STAGED_STATE,
        process_types:                { 'web' => 'started' },
        staging_memory_in_mb:         123,
        staging_disk_in_mb:           456,
        execution_metadata:           'black-box-secrets',
        error:                        'example-error'
      )
    end

    let(:per_page) { 2 }
    let(:order_by) { '-created_at' }

    before do
      droplet1.buildpack_lifecycle_data.update(buildpack: buildpack.name, stack: 'stack-1')
      droplet2.buildpack_lifecycle_data.update(buildpack: 'http://buildpack.git.url.com', stack: 'stack-2')
    end

    it 'filters by states' do
      get "/v3/packages/#{package_model.guid}/droplets?states=STAGED", nil, developer_headers

      expect(last_response.status).to eq(200)
      expect(parsed_response['pagination']).to be_a_response_like(
        {
          'total_results' => 1,
          'total_pages'   => 1,
          'first'         => { 'href' => "/v3/packages/#{package_model.guid}/droplets?page=1&per_page=50&states=STAGED" },
          'last'          => { 'href' => "/v3/packages/#{package_model.guid}/droplets?page=1&per_page=50&states=STAGED" },
          'next'          => nil,
          'previous'      => nil,
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
          'total_pages'   => 1,
          'first'         => { 'href' => "/v3/packages/#{package_model.guid}/droplets?order_by=#{order_by}&page=1&per_page=2" },
          'last'          => { 'href' => "/v3/packages/#{package_model.guid}/droplets?order_by=#{order_by}&page=1&per_page=2" },
          'next'          => nil,
          'previous'      => nil,
        },
        'resources' => [
          {
            'guid'                  => droplet2.guid,
            'state'                 => VCAP::CloudController::DropletModel::STAGED_STATE,
            'error'                 => 'example-error',
            'lifecycle'             => {
              'type' => 'buildpack',
              'data' => {
                'buildpack' => 'http://buildpack.git.url.com',
                'stack'     => 'stack-2'
              }
            },
            'staging_memory_in_mb'  => 123,
            'staging_disk_in_mb'    => 456,
            'result'                => {
              'hash'                   => { 'type' => 'sha1', 'value' => 'my-hash' },
              'buildpack'              => 'http://buildpack.git.url.com',
              'stack'                  => 'stack-2',
              'execution_metadata'     => '[PRIVATE DATA HIDDEN IN LISTS]',
              'process_types'          => { 'redacted_message' => '[PRIVATE DATA HIDDEN IN LISTS]' }
            },
            'environment_variables' => { 'redacted_message' => '[PRIVATE DATA HIDDEN IN LISTS]' },
            'created_at'            => iso8601,
            'updated_at'            => iso8601,
            'links'                 => {
              'self'                   => { 'href' => "/v3/droplets/#{droplet2.guid}" },
              'package'                => { 'href' => "/v3/packages/#{package_model.guid}" },
              'app'                    => { 'href' => "/v3/apps/#{app_model.guid}" },
              'assign_current_droplet' => { 'href' => "/v3/apps/#{app_model.guid}/droplets/current", 'method' => 'PUT' },
            }
          },
          {
            'guid'                  => droplet1.guid,
            'state'                 => VCAP::CloudController::DropletModel::PENDING_STATE,
            'error'                 => 'example-error',
            'lifecycle'             => {
              'type' => 'buildpack',
              'data' => {
                'buildpack' => buildpack.name,
                'stack'     => 'stack-1'
              }
            },
            'staging_memory_in_mb'  => 123,
            'staging_disk_in_mb'    => 235,
            'result'                => nil,
            'environment_variables' => { 'redacted_message' => '[PRIVATE DATA HIDDEN IN LISTS]' },
            'created_at'            => iso8601,
            'updated_at'            => iso8601,
            'links'                 => {
              'self'                   => { 'href' => "/v3/droplets/#{droplet1.guid}" },
              'package'                => { 'href' => "/v3/packages/#{package_model.guid}" },
              'app'                    => { 'href' => "/v3/apps/#{app_model.guid}" },
              'assign_current_droplet' => { 'href' => "/v3/apps/#{app_model.guid}/droplets/current", 'method' => 'PUT' },
              'buildpack'              => { 'href' => "/v2/buildpacks/#{buildpack.guid}" }
            }
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
        state:                       VCAP::CloudController::DropletModel::STAGED_STATE,
        app_guid:                    app_model.guid,
        package_guid:                package_model.guid,
        buildpack_receipt_buildpack: 'http://buildpack.git.url.com',
        buildpack_receipt_stack_name: 'stack-name',
        error:                       nil,
        environment_variables:       { 'cloud' => 'foundry' },
        execution_metadata: 'some-data',
        droplet_hash: 'shalalala',
        process_types: { 'web' => 'start-command' },
        staging_memory_in_mb: 100,
        staging_disk_in_mb: 200,
      )
    end
    let(:app_guid) { droplet_model.app_guid }
    let(:copy_request_json) do {
        relationships: {
          app: { guid: new_app.guid }
        }
      }.to_json
    end
    before do
      og_droplet.buildpack_lifecycle_data.update(buildpack: 'http://buildpack.git.url.com', stack: 'stack-name')
    end

    it 'copies a droplet' do
      post "/v3/droplets/#{og_droplet.guid}/copy", copy_request_json, json_headers(developer_headers)

      parsed_response = MultiJson.load(last_response.body)
      copied_droplet = VCAP::CloudController::DropletModel.last

      expect(last_response.status).to eq(201)
      expect(parsed_response).to be_a_response_like({
        'guid'                  => copied_droplet.guid,
        'state'                 => VCAP::CloudController::DropletModel::PENDING_STATE,
        'error'                 => nil,
        'lifecycle'             => {
          'type' => 'buildpack',
          'data' => {
            'buildpack' => 'http://buildpack.git.url.com',
            'stack'     => 'stack-name'
          }
        },
        'staging_memory_in_mb'  => 100,
        'staging_disk_in_mb'    => 200,
        'result'                => nil,
        'environment_variables' => {},
        'created_at'            => iso8601,
        'updated_at'            => nil,
        'links'                 => {
          'self'                   => { 'href' => "/v3/droplets/#{copied_droplet.guid}" },
          'package'                => nil,
          'app'                    => { 'href' => "/v3/apps/#{new_app.guid}" },
          'assign_current_droplet' => { 'href' => "/v3/apps/#{new_app.guid}/droplets/current", 'method' => 'PUT' },
        }
      })
    end
  end
end
