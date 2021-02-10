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

  let(:guid) { droplet_model.guid }
  let(:package_model) { VCAP::CloudController::PackageModel.make(app_guid: app_model.guid) }
  let(:app_guid) { droplet_model.app_guid }

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
        expect(last_response).to have_error_message(/must be an object/)
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
            'download' => { 'href' => "#{link_prefix}/v3/droplets/#{guid}/download" },
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

  describe 'GET /v3/droplets/:guid/download' do
    let(:worlds_smallest_tgz_file) { "\x1f\x8b\x08\x00\x5e\xc2\xc6\x5e\x00\x03\x63\x60\x18\x05\xa3\x60\x14\x8c\x54\x00\x00\x2e\xaf\xb5\xef\x00\x04\x00\x00" }
    let!(:droplet_model) do
      VCAP::CloudController::DropletModel.make(
        state: VCAP::CloudController::DropletModel::AWAITING_UPLOAD_STATE,
        app_guid: app_model.guid,
        package_guid: package_model.guid,
        buildpack_receipt_buildpack: 'http://buildpack.git.url.com',
        error_description: 'example error',
        execution_metadata: 'some-data',
        droplet_hash: Digest::SHA1.hexdigest(worlds_smallest_tgz_file),
        sha256_checksum: 'some-sha-256',
        process_types: { 'web' => 'start-command' },
      )
    end

    let(:droplet_file) do
      File.join(Dir.mktmpdir(nil, '/tmp'), 'droplet.tgz')
    end
    let(:upload_body) do
      {
        bits_name: 'droplet.tgz',
        bits_path: droplet_file,
      }
    end
    let(:bits_download_url) { CloudController::DependencyLocator.instance.blobstore_url_generator.droplet_download_url(droplet_model) }

    context 'when the droplet is uploaded' do
      let(:api_call) { lambda { |user_headers| get "/v3/droplets/#{guid}/download", nil, user_headers } }
      let(:expected_codes_and_responses) do
        h = Hash.new(
          code: 302
        )
        h['org_auditor'] = {
          code: 404
        }
        h['org_billing_manager'] = {
          code: 404
        }
        h['no_role'] = {
          code: 404
        }
        h.freeze
      end

      before do
        File.write(droplet_file, worlds_smallest_tgz_file)
        post "/v3/droplets/#{guid}/upload", upload_body.to_json, developer_headers
        expect(last_response).to have_status_code(202)
        successes, failures = Delayed::Worker.new.work_off
        expect(successes).to eq(1)
        expect(failures).to eq(0)
      end

      it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS

      it 'downloads the bit(s) for a droplet' do
        get "/v3/droplets/#{guid}/download", nil, developer_headers

        expect(last_response.status).to eq(302)
        expect(last_response.headers['Location']).to eq(bits_download_url)

        expected_metadata = { droplet_guid: droplet_model.guid }.to_json

        event = VCAP::CloudController::Event.last
        expect(event.values).to include({
          type: 'audit.app.droplet.download',
          actor_username: user_name,
          metadata: expected_metadata,
          space_guid: space.guid,
          organization_guid: space.organization.guid
        })
      end

      context 'when the blob cannot be found' do
        let(:fake_blobstore) { instance_double(VCAP::CloudController::BlobDispatcher) }

        before do
          allow_any_instance_of(VCAP::CloudController::BlobDispatcher).to receive(:send_or_redirect).and_raise(CloudController::Errors::BlobNotFound)
        end

        it 'returns 502 for the blob' do
          get "/v3/droplets/#{guid}/download", nil, developer_headers
          expect(last_response).to have_status_code(502)
          expect(last_response.body).to include('Failed to perform operation due to blobstore unavailability.')
        end
      end
    end

    context 'when the droplet cannot be retrieved from the blobstore' do
      before do
        droplet_model.update(
          state: VCAP::CloudController::DropletModel::STAGED_STATE,
          droplet_hash: nil
        )
      end

      it 'returns an error with a helpful message' do
        get "/v3/droplets/#{droplet_model.guid}/download", nil, developer_headers
        expect(last_response).to have_status_code(404)
        expect(last_response).to have_error_message('Blobstore key not present on droplet. This may be due to a failed build.')
      end
    end

    context 'when the droplet cannot be found' do
      it 'returns 404 for the droplet' do
        get '/v3/droplets/some-bogus-guid/download', nil, developer_headers
        expect(last_response.status).to eq(404)
        expect(last_response.body).to include('Droplet not found')
      end
    end

    context "when the droplet hasn't finished uploading/processing" do
      it 'returns a 422 with a helpful error message' do
        get "/v3/droplets/#{guid}/download", nil, developer_headers
        expect(last_response.status).to eq(422)
        expect(last_response.body).to include('Only staged droplets can be downloaded.')
      end
    end

    context "when the droplet has type 'docker'" do
      let!(:droplet_model) do
        VCAP::CloudController::DropletModel.make(:docker)
      end

      it 'returns a 422 with a helpful error message' do
        get "/v3/droplets/#{guid}/download", nil, admin_headers
        expect(last_response.status).to eq(422)
        expect(last_response.body).to include("Cannot download droplets with 'docker' lifecycle.")
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
    let(:droplet1_json) do
      {
        guid: droplet1.guid,
        created_at: iso8601,
        updated_at: iso8601,
        state: droplet1.state,
        error: droplet1.error,
        lifecycle: {
          type: droplet1.lifecycle_type,
          data: {},
        },
        checksum: nil,
        buildpacks: [
          {
            name: buildpack.name,
            detect_output: nil,
            buildpack_name: nil,
            version: nil
          }
        ],
        stack: droplet1.lifecycle_data.try(:stack),
        image: nil,
        execution_metadata: '[PRIVATE DATA HIDDEN IN LISTS]',
        process_types: { redacted_message: '[PRIVATE DATA HIDDEN IN LISTS]' },
        relationships: { app: { data: { guid: droplet1.app_guid } } },
        metadata: {
          labels: {},
          annotations: {},
        },
        links: {
          self: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/droplets\/#{droplet1.guid}) },
          app: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/apps\/#{droplet1.app_guid}) },
          assign_current_droplet: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/apps/#{droplet1.app_guid}/relationships/current_droplet), method: 'PATCH' },
          package: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/packages\/#{package_model.guid}) },
        }
      }
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
    let(:droplet2_json) do
      {
        guid: droplet2.guid,
        created_at: iso8601,
        updated_at: iso8601,
        state: droplet2.state,
        error: droplet2.error,
        lifecycle: {
          type: droplet2.lifecycle_type,
          data: {},
        },
        checksum: { type: 'sha256', value: 'droplet-checksum-sha256' },
        buildpacks: [
          {
            name: 'http://buildpack.git.url.com',
            detect_output: nil,
            buildpack_name: nil,
            version: nil
          }
        ],
        stack: droplet2.lifecycle_data.try(:stack),
        image: droplet2.docker_receipt_image,
        execution_metadata: '[PRIVATE DATA HIDDEN IN LISTS]',
        process_types: { redacted_message: '[PRIVATE DATA HIDDEN IN LISTS]' },
        relationships: { app: { data: { guid: droplet2.app_guid } } },
        metadata: {
          labels: {},
          annotations: {},
        },
        links: {
          self: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/droplets\/#{droplet2.guid}) },
          app: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/apps\/#{droplet2.app_guid}) },
          assign_current_droplet: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/apps/#{droplet2.app_guid}/relationships/current_droplet), method: 'PATCH' },
          download: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/droplets\/#{droplet2.guid}\/download) },
          package: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/packages\/#{package_model.guid}) },
        },
      }
    end
    let(:api_call) { lambda { |user_headers| get '/v3/droplets', nil, user_headers } }

    let(:per_page) { 2 }
    let(:order_by) { '-created_at' }

    before do
      droplet1.buildpack_lifecycle_data.update(buildpacks: [buildpack.name], stack: 'stack-1')
      droplet2.buildpack_lifecycle_data.update(buildpacks: ['http://buildpack.git.url.com'], stack: 'stack-2')
    end

    it_behaves_like 'list query endpoint' do
      let(:request) { 'v3/droplets' }
      let(:message) { VCAP::CloudController::DropletsListMessage }
      let(:user_header) { developer_headers }
      let(:excluded_params) do
        [
          :current,
          :app_guid
        ]
      end
      let(:params) do
        {
          page: '2',
          per_page: '10',
          order_by: 'updated_at',
          guids: 'foo,bar',
          app_guids: 'foo,bar',
          package_guid: package_model.guid,
          space_guids: 'test',
          states: ['test', 'foo'],
          organization_guids: 'foo,bar',
          label_selector: 'foo,bar',
          created_ats:  "#{Time.now.utc.iso8601},#{Time.now.utc.iso8601}",
          updated_ats: { gt: Time.now.utc.iso8601 },
        }
      end
    end

    it_behaves_like 'list query endpoint' do
      let(:request) { 'v3/droplets' }
      let(:message) { VCAP::CloudController::DropletsListMessage }
      let(:user_header) { developer_headers }
      let(:excluded_params) do
        [
          :space_guids,
          :app_guids,
          :organization_guids
        ]
      end
      let(:params) do
        {
          page: '2',
          per_page: '10',
          order_by: 'updated_at',
          guids: 'foo,bar',
          app_guid: app_model.guid,
          current: true,
          package_guid: package_model.guid,
          states: ['test', 'foo'],
          label_selector: 'foo,bar',
          created_ats:  "#{Time.now.utc.iso8601},#{Time.now.utc.iso8601}",
          updated_ats: { gt: Time.now.utc.iso8601 },
        }
      end
    end

    context 'when the user is a member in the droplets space' do
      let(:other_space) { VCAP::CloudController::Space.make }
      let(:other_app_model) { VCAP::CloudController::AppModel.make(space_guid: other_space.guid, name: 'my-other-app') }
      let(:other_package_model) do
        VCAP::CloudController::PackageModel.make(
          app_guid: other_app_model.guid,
          type: VCAP::CloudController::PackageModel::BITS_TYPE
        )
      end
      let(:droplet_in_other_space) do
        VCAP::CloudController::DropletModel.make(
          app_guid: other_app_model.guid,
          package_guid: other_package_model.guid,
          droplet_hash: nil,
          sha256_checksum: nil,
          buildpack_receipt_buildpack: buildpack.name,
          buildpack_receipt_buildpack_guid: buildpack.guid,
          staging_disk_in_mb: 235,
          state: VCAP::CloudController::DropletModel::STAGED_STATE
        )
      end
      let(:droplet_in_other_space_json) do
        {
          guid: droplet_in_other_space.guid,
          created_at: iso8601,
          updated_at: iso8601,
          state: droplet_in_other_space.state,
          error: nil,
          lifecycle: {
            type: droplet_in_other_space.lifecycle_type,
            data: {},
          },
          checksum: nil,
          buildpacks: [],
          stack: droplet_in_other_space.lifecycle_data.try(:stack),
          image: nil,
          execution_metadata: '[PRIVATE DATA HIDDEN IN LISTS]',
          process_types: { redacted_message: '[PRIVATE DATA HIDDEN IN LISTS]' },
          relationships: { app: { data: { guid: droplet_in_other_space.app_guid } } },
          metadata: {
            labels: {},
            annotations: {},
          },
          links: {
            self: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/droplets\/#{droplet_in_other_space.guid}) },
            app: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/apps\/#{droplet_in_other_space.app_guid}) },
            assign_current_droplet: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/apps/#{droplet_in_other_space.app_guid}/relationships/current_droplet), method: 'PATCH' },
            package: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/packages\/#{other_package_model.guid}) },
            download: { href: %r(#{Regexp.escape(link_prefix)}\/v3\/droplets\/#{droplet_in_other_space.guid}\/download) },
          }
        }
      end

      let(:expected_codes_and_responses) do
        h = Hash.new(
          code: 200,
          response_objects: [droplet1_json, droplet2_json]
        )

        h['admin'] = { code: 200, response_objects: [droplet1_json, droplet2_json, droplet_in_other_space_json] }
        h['admin_read_only'] = { code: 200, response_objects: [droplet1_json, droplet2_json, droplet_in_other_space_json] }
        h['global_auditor'] = { code: 200, response_objects: [droplet1_json, droplet2_json, droplet_in_other_space_json] }

        h['org_auditor'] = { code: 200, response_objects: [] }
        h['org_billing_manager'] = { code: 200, response_objects: [] }
        h['no_role'] = { code: 200, response_objects: [] }
        h
      end

      it_behaves_like 'permissions for list endpoint', ALL_PERMISSIONS
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
              'download' => { 'href' => "#{link_prefix}/v3/droplets/#{droplet2.guid}/download" },
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

    context 'filtering by timestamps' do
      before do
        VCAP::CloudController::DropletModel.plugin :timestamps, update_on_create: false

        # Delete all the existing DropletModels so they don't overlap in timestamp with our queries
        VCAP::CloudController::DropletModel.dataset.delete
      end

      # .make updates the resource after creating it, over writing our passed in updated_at timestamp
      # Therefore we cannot use shared_examples as the updated_at will not be as written
      let!(:resource_1) {
        VCAP::CloudController::DropletModel.create(
          state: VCAP::CloudController::DropletModel::STAGED_STATE,
          created_at: '2020-05-26T18:47:01Z',
          updated_at: '2020-05-26T18:47:01Z',
          app: app_model)
      }
      let!(:resource_2) {
        VCAP::CloudController::DropletModel.create(
          state: VCAP::CloudController::DropletModel::STAGED_STATE,
          created_at: '2020-05-26T18:47:02Z',
          updated_at: '2020-05-26T18:47:02Z',
          app: app_model)
      }
      let!(:resource_3) {
        VCAP::CloudController::DropletModel.create(
          state: VCAP::CloudController::DropletModel::STAGED_STATE,
          created_at: '2020-05-26T18:47:03Z',
          updated_at: '2020-05-26T18:47:03Z',
          app: app_model)
      }
      let!(:resource_4) {
        VCAP::CloudController::DropletModel.create(
          state: VCAP::CloudController::DropletModel::STAGED_STATE,
          created_at: '2020-05-26T18:47:04Z',
          updated_at: '2020-05-26T18:47:04Z',
          app: app_model)
      }

      after do
        VCAP::CloudController::DropletModel.plugin :timestamps, update_on_create: true
      end

      it 'filters by the created at' do
        get "/v3/droplets?created_ats[lt]=#{resource_3.created_at.iso8601}", nil, admin_headers

        expect(last_response).to have_status_code(200)
        expect(parsed_response['resources'].map { |r| r['guid'] }).to contain_exactly(resource_1.guid, resource_2.guid)
      end

      it 'filters by the updated_at' do
        get "/v3/droplets?updated_ats[lt]=#{resource_3.updated_at.iso8601}", nil, admin_headers

        expect(last_response).to have_status_code(200)
        expect(parsed_response['resources'].map { |r| r['guid'] }).to contain_exactly(resource_1.guid, resource_2.guid)
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

    context 'deleting metadata' do
      it_behaves_like 'resource with metadata' do
        let(:resource) { droplet }
        let(:api_call) do
          -> { delete "/v3/droplets/#{droplet.guid}", nil, developer_headers }
        end
      end
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
              'download' => { 'href' => "#{link_prefix}/v3/droplets/#{droplet2.guid}/download" },
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
              'download' => { 'href' => "#{link_prefix}/v3/droplets/#{droplet2.guid}/download" },
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

    let(:metadata) do
      {
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
    end

    let(:update_request) do
      {
        metadata: metadata
      }
    end

    before do
      og_droplet.buildpack_lifecycle_data.update(buildpacks: ['http://buildpack.git.url.com'], stack: 'stack-name')
    end

    context 'when the droplet does not exist' do
      it 'returns a 404' do
        patch '/v3/droplets/POTATO', { metadata: metadata }.to_json, developer_headers
        expect(last_response).to have_status_code(404)
      end
    end
    context 'when the droplet exists' do
      context 'when the message is invalid' do
        let(:update_request) do
          { metadata: 567 }
        end

        it 'returns 422 and renders the errors' do
          patch "/v3/droplets/#{og_droplet.guid}", update_request.to_json, admin_headers
          expect(last_response).to have_status_code(422)
          expect(last_response.body).to include('UnprocessableEntity')
        end
      end

      it 'cloud_controller returns 403 if not admin and not build_state_updater' do
        patch "/v3/droplets/#{og_droplet.guid}", { metadata: metadata }.to_json, headers_for(make_auditor_for_space(space), user_name: user_name, email: 'bob@loblaw.com')
        expect(last_response.status).to eq(403), last_response.body
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

      context 'when updating the image (on a docker droplet)' do
        let(:app_model) { VCAP::CloudController::AppModel.make(:docker, space_guid: space.guid, name: 'my-docker-app') }
        let(:package_model) { VCAP::CloudController::PackageModel.make(app_guid: app_model.guid) }
        let(:rebased_image_reference) { 'rebased-image-reference' }
        let!(:og_docker_droplet) do
          VCAP::CloudController::DropletModel.make(
            :kpack,
            state: VCAP::CloudController::DropletModel::STAGED_STATE,
            app_guid: app_model.guid,
            package_guid: package_model.guid,
            droplet_hash: 'shalalala',
            sha256_checksum: 'droplet-checksum-sha256',
          )
        end
        before do
          og_docker_droplet.update(docker_receipt_image: 'some-image-reference')
        end
        let(:update_request) do
          {
            image: rebased_image_reference
          }
        end
        it 'allows admins to update the image' do
          patch "/v3/droplets/#{og_docker_droplet.guid}", update_request.to_json, admin_headers
          expect(last_response.status).to eq(200), last_response.body

          og_docker_droplet.reload
          parsed_response = MultiJson.load(last_response.body)
          expect(parsed_response['image']).to eq(
            rebased_image_reference
          )
        end

        context 'when the cloud_controller.update_build_state scope is present' do
          it 'updates the image' do
            patch "/v3/droplets/#{og_docker_droplet.guid}", update_request.to_json, build_state_updater_headers
            expect(last_response.status).to eq(200)

            og_docker_droplet.reload
            parsed_response = MultiJson.load(last_response.body)
            expect(parsed_response['image']).to eq(
              rebased_image_reference
            )
          end
        end

        context 'when the cloud_controller.update_build_state scope is NOT present' do
          it '403s' do
            patch "/v3/droplets/#{og_docker_droplet.guid}", update_request.to_json, developer_headers
            expect(last_response.status).to eq(403), last_response.body
          end
        end

        context 'when the the developer is looking in the wrong space' do
          let(:wrong_developer) { make_developer_for_space(VCAP::CloudController::Space.make) }
          let(:wrong_developer_headers) { headers_for(wrong_developer, user_name: user_name, email: 'bob@loblaw.com') }

          it '404s' do
            patch "/v3/droplets/#{og_docker_droplet.guid}", update_request.to_json, wrong_developer_headers
            expect(last_response.status).to eq(404), last_response.body
          end
        end
      end
    end
  end
end
