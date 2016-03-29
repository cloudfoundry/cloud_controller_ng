require 'spec_helper'

describe 'Droplets' do
  let(:space) { VCAP::CloudController::Space.make }
  let(:app_model) { VCAP::CloudController::AppModel.make(space_guid: space.guid) }
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
    let!(:package) {
      VCAP::CloudController::PackageModel.make(
        app_guid: app_model.guid,
        state:    VCAP::CloudController::PackageModel::READY_STATE,
        type:     VCAP::CloudController::PackageModel::BITS_TYPE,
        url:      'hello.com'
      )
    }
    let(:create_request_json) {
      {
        environment_variables: { 'CUSTOMENV' => 'env value' },
        memory_limit:          1024,
        disk_limit:            4096,
        lifecycle:             {
          type: 'buildpack',
          data: {
            stack:     'cflinuxfs2',
            buildpack: 'http://github.com/myorg/awesome-buildpack'
          }
        },
      }.to_json
    }

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
      expect {
        post "/v3/packages/#{package.guid}/droplets", create_request_json, json_headers(developer_headers)
      }.to change { VCAP::CloudController::DropletModel.count }.by(1)

      expect(last_response.status).to eq(201)
    end

    it 'responds with links to access related resources' do
      post "/v3/packages/#{package.guid}/droplets", create_request_json, json_headers(developer_headers)
      expect(parsed_response['links']).to be_a_response_like({
        'self'                   => { 'href' => "/v3/droplets/#{VCAP::CloudController::DropletModel.last.guid}" },
        'package'                => { 'href' => "/v3/packages/#{package.guid}" },
        'app'                    => { 'href' => "/v3/apps/#{app_model.guid}" },
        'assign_current_droplet' => {
          'href'   => "/v3/apps/#{app_model.guid}/current_droplet",
          'method' => 'PUT'
        }
      })
    end

    it 'creates a droplet with requested environment variables merged into defaults' do
      post "/v3/packages/#{package.guid}/droplets", create_request_json, json_headers(developer_headers)
      expect(parsed_response['environment_variables']).to be_a_response_like({
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
      })
    end
  end

  describe 'GET /v3/droplets/:guid' do
    let(:guid) { droplet_model.guid }
    let(:buildpack_git_url) { 'http://buildpack.git.url.com' }
    let(:package_model) { VCAP::CloudController::PackageModel.make(app_guid: app_model.guid) }
    let!(:droplet_model) do
      VCAP::CloudController::DropletModel.make(
        :buildpack,
        state:                       VCAP::CloudController::DropletModel::STAGED_STATE,
        app_guid:                    app_model.guid,
        package_guid:                package_model.guid,
        buildpack_receipt_buildpack: buildpack_git_url,
        error:                       'example error',
        environment_variables:       { 'cloud' => 'foundry' },
      )
    end
    let(:app_guid) { droplet_model.app_guid }

    it 'gets a droplet' do
      get "/v3/droplets/#{droplet_model.guid}", nil, developer_headers
      expect(last_response.status).to eq(200)
      expect(parsed_response).to be_a_response_like({
        'guid'                  => droplet_model.guid,
        'state'                 => droplet_model.state,
        'error'                 => droplet_model.error,
        'lifecycle'             => {
          'type' => 'buildpack',
          'data' => {
            'buildpack' => droplet_model.lifecycle_data.buildpack,
            'stack'     => droplet_model.lifecycle_data.stack,
          }
        },
        'memory_limit'          => droplet_model.memory_limit,
        'disk_limit'            => droplet_model.disk_limit,
        'result'                => {
          'execution_metadata' => droplet_model.execution_metadata,
          'process_types'      => droplet_model.process_types,
          'hash'               => { 'type' => 'sha1', 'value' => droplet_model.droplet_hash },
          'buildpack'          => droplet_model.buildpack_receipt_buildpack,
          'stack'              => droplet_model.buildpack_receipt_stack_name
        },
        'environment_variables' => droplet_model.environment_variables,
        'created_at'            => iso8601,
        'updated_at'            => iso8601,
        'links'                 => {
          'self'                   => { 'href' => "/v3/droplets/#{guid}" },
          'package'                => { 'href' => "/v3/packages/#{package_model.guid}" },
          'app'                    => { 'href' => "/v3/apps/#{app_guid}" },
          'assign_current_droplet' => {
            'href'   => "/v3/apps/#{app_guid}/current_droplet",
            'method' => 'PUT'
          }
        }
      })
    end
  end

  describe 'GET /v3/droplets' do
    let(:buildpack) { VCAP::CloudController::Buildpack.make }
    let(:package) do
      VCAP::CloudController::PackageModel.make(
        app_guid: app_model.guid,
        type:     VCAP::CloudController::PackageModel::BITS_TYPE
      )
    end

    let!(:droplet1) do
      VCAP::CloudController::DropletModel.make(
        :buildpack,
        app_guid:                         app_model.guid,
        created_at:                       Time.at(1),
        package_guid:                     package.guid,
        buildpack_receipt_buildpack:      buildpack.name,
        buildpack_receipt_buildpack_guid: buildpack.guid,
        environment_variables:            { 'yuu' => 'huuu' }
      )
    end
    let!(:droplet2) do
      VCAP::CloudController::DropletModel.make(
        :buildpack,
        app_guid:                    app_model.guid,
        created_at:                  Time.at(2),
        package_guid:                package.guid,
        droplet_hash:                'my-hash',
        buildpack_receipt_buildpack: 'https://github.com/cloudfoundry/detected-buildpack.git',
        state:                       VCAP::CloudController::DropletModel::STAGED_STATE,
        process_types:               { 'web' => 'started' },
        memory_limit:                123,
        disk_limit:                  456,
        execution_metadata:          'black-box-secrets'
      )
    end

    let(:page) { 1 }
    let(:per_page) { 2 }
    let(:order_by) { '-created_at' }

    before do
      VCAP::CloudController::BuildpackLifecycleDataModel.make(droplet: droplet2)
      VCAP::CloudController::BuildpackLifecycleDataModel.make(droplet: droplet1)
    end

    it 'list all droplets with a buildpack lifecycle' do
      get '/v3/droplets', nil, developer_headers
      expect(last_response.status).to eq(200)
      expect(parsed_response['resources']).to include(hash_including('guid' => droplet1.guid))
      expect(parsed_response['resources']).to include(hash_including('guid' => droplet2.guid))
    end

    it 'includes pagination in the response' do
      get "/v3/droplets?order_by=#{order_by}", nil, developer_headers
      expect(parsed_response['pagination']).to be_a_response_like({
        'total_results' => 2,
        'first'         => { 'href' => "/v3/droplets?order_by=#{order_by}&page=1&per_page=50" },
        'last'          => { 'href' => "/v3/droplets?order_by=#{order_by}&page=1&per_page=50" },
        'next'          => nil,
        'previous'      => nil,
      })
    end

    context 'when a droplet does not have a buildpack lifecycle' do
      let!(:droplet_without_lifecycle) { VCAP::CloudController::DropletModel.make(:buildpack, package_guid: VCAP::CloudController::PackageModel.make.guid) }

      it 'is excluded' do
        get '/v3/droplets', nil, developer_headers
        expect(parsed_response['resources']).not_to include(hash_including('guid' => droplet_without_lifecycle.guid))
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
    let(:package) do
      VCAP::CloudController::PackageModel.make(
        app_guid: app_model.guid,
        type:     VCAP::CloudController::PackageModel::BITS_TYPE
      )
    end
    let!(:droplet1) do
      VCAP::CloudController::DropletModel.make(
        :buildpack,
        app_guid:                         app_model.guid,
        created_at:                       Time.at(1),
        package_guid:                     package.guid,
        buildpack_receipt_buildpack:      buildpack.name,
        buildpack_receipt_buildpack_guid: buildpack.guid,
        environment_variables:            { 'yuu' => 'huuu' },
        memory_limit:                     123,
      )
    end
    let!(:droplet2) do
      VCAP::CloudController::DropletModel.make(
        :buildpack,
        app_guid:                    app_model.guid,
        created_at:                  Time.at(2),
        package_guid:                package.guid,
        droplet_hash:                'my-hash',
        buildpack_receipt_buildpack: 'https://github.com/cloudfoundry/my-buildpack.git',
        process_types:               { web: 'started' }.to_json,
        state:                       VCAP::CloudController::DropletModel::STAGED_STATE,
        memory_limit:                123,
      )
    end

    let(:excluded_droplet) { VCAP::CloudController::DropletModel.make(:buildpack, package_guid: VCAP::CloudController::PackageModel.make.guid) }

    let(:app_guid) { app_model.guid }
    let(:page) { 1 }
    let(:per_page) { 2 }
    let(:order_by) { '-created_at' }

    before do
      VCAP::CloudController::BuildpackLifecycleDataModel.make(droplet: droplet1)
      VCAP::CloudController::BuildpackLifecycleDataModel.make(droplet: droplet2)
    end

    it 'includes all droplets that are a part of the app' do
      get "/v3/apps/#{app_guid}/droplets?order_by=#{order_by}&per_page=#{per_page}", nil, developer_headers
      expect(last_response.status).to eq(200)
      expect(parsed_response['resources']).to include(hash_including('guid' => droplet1.guid))
      expect(parsed_response['resources']).to include(hash_including('guid' => droplet2.guid))
      expect(parsed_response['resources']).not_to include(hash_including('guid' => excluded_droplet.guid))
    end

    it 'includes pagination in the response' do
      get "/v3/apps/#{app_guid}/droplets?order_by=#{order_by}&per_page=#{per_page}", nil, developer_headers
      expect(parsed_response['pagination']).to be_a_response_like({
        'total_results' => 2,
        'first'         => { 'href' => "/v3/apps/#{app_guid}/droplets?order_by=#{order_by}&page=1&per_page=2" },
        'last'          => { 'href' => "/v3/apps/#{app_guid}/droplets?order_by=#{order_by}&page=1&per_page=2" },
        'next'          => nil,
        'previous'      => nil,
      })
    end

    context 'filtered by state' do
      let(:states) { [VCAP::CloudController::DropletModel::STAGING_STATE, VCAP::CloudController::DropletModel::FAILED_STATE].join(',') }

      it 'filters droplets by state' do
        get "/v3/apps/#{app_guid}/droplets?order_by=#{order_by}&per_page=#{per_page}&states=#{states}", nil, developer_headers
        expect(last_response.status).to eq(200)
        expect(parsed_response['resources']).to include(hash_including('guid' => droplet1.guid))
        expect(parsed_response['resources']).not_to include(hash_including('guid' => droplet2.guid))
      end

      it 'includes the state filter in pagination' do
        get "/v3/apps/#{app_guid}/droplets?order_by=#{order_by}&per_page=#{per_page}&states=#{states}", nil, developer_headers
        expect(last_response.status).to eq(200)
        expect(parsed_response['pagination']).to be_a_response_like({
          'total_results' => 1,
          'first'         => { 'href' => "/v3/apps/#{app_model.guid}/droplets?order_by=#{order_by}&page=1&per_page=2&states=#{CGI.escape(states)}" },
          'last'          => { 'href' => "/v3/apps/#{app_model.guid}/droplets?order_by=#{order_by}&page=1&per_page=2&states=#{CGI.escape(states)}" },
          'next'          => nil,
          'previous'      => nil
        })
      end
    end
  end
end
