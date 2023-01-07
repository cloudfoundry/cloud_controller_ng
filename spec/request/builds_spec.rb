require 'spec_helper'
require 'request_spec_shared_examples'

RSpec.describe 'Builds' do
  let(:bbs_stager_client) { instance_double(VCAP::CloudController::Diego::BbsStagerClient) }
  let(:space) { VCAP::CloudController::Space.make }
  let(:developer) { make_developer_for_space(space) }
  let(:developer_headers) { headers_for(developer, user_name: user_name, email: 'bob@loblaw.com') }

  let(:user_name) { 'bob the builder' }
  let(:parsed_response) { MultiJson.load(last_response.body) }
  let(:app_model) { VCAP::CloudController::AppModel.make(space_guid: space.guid, name: 'my-app') }
  let(:second_app_model) { VCAP::CloudController::AppModel.make(space_guid: space.guid, name: 'my-second-app') }
  let(:rails_logger) { double('rails_logger', info: nil) }

  describe 'POST /v3/builds' do
    let(:package) do
      VCAP::CloudController::PackageModel.make(
        app_guid: app_model.guid,
        state: VCAP::CloudController::PackageModel::READY_STATE,
        type: VCAP::CloudController::PackageModel::BITS_TYPE,
      )
    end
    let(:diego_staging_response) do
      {
        execution_metadata: 'String',
        detected_start_command: {},
        lifecycle_data: {
          buildpack_key: 'String',
          detected_buildpack: 'String',
        }
      }
    end
    let(:create_request) do
      {
        lifecycle: {
          type: 'buildpack',
          data: {
            buildpacks: ['http://github.com/myorg/awesome-buildpack'],
            stack: 'cflinuxfs4'
          },
        },
        package: {
          guid: package.guid
        }
      }
    end
    let(:metadata) {
      {
        labels: {
          release: 'stable',
          'seriouseats.com/potato' => 'mashed',
        },
        annotations: {
          potato: 'idaho',
        },
      }
    }

    before do
      allow_any_instance_of(CloudController::Blobstore::UrlGenerator).to receive(:package_download_url).and_return('some-string')
      allow_any_instance_of(CloudController::Blobstore::UrlGenerator).to receive(:package_droplet_upload_url).and_return('some-string')
      CloudController::DependencyLocator.instance.register(:bbs_stager_client, bbs_stager_client)
      allow(bbs_stager_client).to receive(:stage)
    end

    it 'creates a Builds resource' do
      post '/v3/builds', create_request.merge(metadata: metadata).to_json, developer_headers
      expect(last_response.status).to eq(201), last_response.body

      created_build = VCAP::CloudController::BuildModel.last

      expected_response =
        {
          'guid' => created_build.guid,
          'created_at' => iso8601,
          'updated_at' => iso8601,
          'state' => 'STAGING',
          'staging_memory_in_mb' => 42,
          'staging_disk_in_mb' => 42,
          'staging_log_rate_limit_bytes_per_second' => -1,
          'metadata' => { 'labels' => { 'release' => 'stable', 'seriouseats.com/potato' => 'mashed' }, 'annotations' => { 'potato' => 'idaho' } },
          'error' => nil,
          'lifecycle' => {
            'type' => 'buildpack',
            'data' => {
              'buildpacks' => ['http://github.com/myorg/awesome-buildpack'],
              'stack' => 'cflinuxfs4'
            },
          },
          'package' => {
            'guid' => package.guid
          },
          'droplet' => nil,
          'relationships' => { 'app' => { 'data' => { 'guid' => app_model.guid } } },
          'links' => {
            'self' => {
              'href' => "#{link_prefix}/v3/builds/#{created_build.guid}"
            },
            'app' => {
              'href' => "#{link_prefix}/v3/apps/#{package.app.guid}"
            }
          },
          'created_by' => {
            'guid' => developer.guid,
            'name' => 'bob the builder',
            'email' => 'bob@loblaw.com',
          }
        }

      expect(last_response.status).to eq(201)
      expect(parsed_response).to be_a_response_like(expected_response)

      event = VCAP::CloudController::Event.last
      expect(event).not_to be_nil
      expect(event.type).to eq('audit.app.build.create')
      expect(event.metadata).to eq({
        'build_guid' => created_build.guid,
        'package_guid' => package.guid,
      })
    end

    context 'permissions' do
      let(:api_call) { lambda { |user_headers| post '/v3/builds', create_request.to_json, user_headers } }
      let(:org) { space.organization }
      let(:user) { VCAP::CloudController::User.make }

      let(:expected_codes_and_responses) do
        h = Hash.new(
          code: 422
        )
        h['admin'] = {
          code: 201,
        }
        h['space_developer'] = {
          code: 201,
        }
        h['space_supporter'] = {
          code: 201,
        }
        h
      end

      let(:expected_event_hash) do
        {
          type: 'audit.app.build.create',
          actee: app_model.guid,
          actee_type: 'app',
          actee_name: app_model.name,
          metadata: { build_guid: parsed_response['guid'], package_guid: parsed_response['package']['guid'] }.to_json,
          space_guid: space.guid,
          organization_guid: org.guid,
        }
      end

      it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS

      context 'when organization is suspended' do
        let(:expected_codes_and_responses) do
          h = super()
          %w[space_developer space_supporter].each { |r| h[r] = { code: 422 } }
          h
        end

        before do
          org.update(status: VCAP::CloudController::Organization::SUSPENDED)
        end

        it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS
      end
    end

    context 'telemetry' do
      let(:logger_spy) { spy('logger') }

      before do
        allow(VCAP::CloudController::TelemetryLogger).to receive(:logger).and_return(logger_spy)
      end

      it 'should log the required fields when the build is created' do
        Timecop.freeze do
          post '/v3/builds', create_request.merge(metadata: metadata).to_json, developer_headers
          created_build = VCAP::CloudController::BuildModel.last
          expected_json = {
            'telemetry-source' => 'cloud_controller_ng',
            'telemetry-time' => Time.now.to_datetime.rfc3339,
            'create-build' => {
              'api-version' => 'v3',
              'lifecycle' => 'buildpack',
              'buildpacks' => ['http://github.com/myorg/awesome-buildpack'],
              'stack' => 'cflinuxfs4',
              'app-id' => OpenSSL::Digest::SHA256.hexdigest(app_model.guid),
              'build-id' => OpenSSL::Digest::SHA256.hexdigest(created_build.guid),
              'user-id' => OpenSSL::Digest::SHA256.hexdigest(developer.guid),
            }
          }
          expect(logger_spy).to have_received(:info).with(JSON.generate(expected_json))
          expect(last_response.status).to eq(201), last_response.body
        end
      end
    end
  end

  describe 'GET /v3/builds' do
    let(:build) do
      VCAP::CloudController::BuildModel.make(
        package: package,
        app: app_model,
        created_by_user_name: 'bob the builder',
        created_by_user_guid: developer.guid,
        created_by_user_email: 'bob@loblaw.com',
        staging_memory_in_mb: 123,
        staging_disk_in_mb: 456,
        staging_log_rate_limit: 234
      )
    end
    let!(:second_build) do
      VCAP::CloudController::BuildModel.make(
        package: second_package,
        app: app_model,
        created_at: build.created_at - 1.day,
        created_by_user_name: 'bob the builder',
        created_by_user_guid: developer.guid,
        created_by_user_email: 'bob@loblaw.com',
        staging_memory_in_mb: 789,
        staging_disk_in_mb: 12,
        staging_log_rate_limit: 345
      )
    end
    let(:package) { VCAP::CloudController::PackageModel.make(app_guid: app_model.guid) }
    let(:second_package) { VCAP::CloudController::PackageModel.make(app_guid: app_model.guid) }
    let(:droplet) { VCAP::CloudController::DropletModel.make(
      state: VCAP::CloudController::DropletModel::STAGED_STATE,
      package_guid: package.guid,
      build: build,
    )
    }
    let(:second_droplet) { VCAP::CloudController::DropletModel.make(
      state: VCAP::CloudController::DropletModel::STAGED_STATE,
      package_guid: second_package.guid,
      build: second_build,
    )
    }
    let(:body) do
      { lifecycle: { type: 'buildpack', data: { buildpacks: ['http://github.com/myorg/awesome-buildpack'],
        stack: 'cflinuxfs4' } } }
    end
    let(:staging_message) { VCAP::CloudController::BuildCreateMessage.new(body) }

    before do
      VCAP::CloudController::BuildpackLifecycle.new(package, staging_message).create_lifecycle_data_model(build)
      VCAP::CloudController::BuildpackLifecycle.new(second_package, staging_message).create_lifecycle_data_model(second_build)
      build.update(state: droplet.state, error_description: droplet.error_description)
      second_build.update(state: second_droplet.state, error_description: second_droplet.error_description)
    end

    it_behaves_like 'list query endpoint' do
      let(:request) { 'v3/builds' }
      let(:user_header) { developer_headers }
      let(:message) { VCAP::CloudController::BuildsListMessage }
      let(:params) do
        {
          page: '2',
          per_page: '10',
          order_by: 'updated_at',
          states: 'foo',
          guids: '123',
          app_guids: '123',
          package_guids: '123',
          label_selector: 'foo,bar',
          created_ats:  "#{Time.now.utc.iso8601},#{Time.now.utc.iso8601}",
          updated_ats: { gt: Time.now.utc.iso8601 },
        }
      end
    end

    it_behaves_like 'list_endpoint_with_common_filters' do
      let(:resource_klass) { VCAP::CloudController::BuildModel }
      let(:api_call) do
        lambda { |headers, filters| get "/v3/builds?#{filters}", nil, headers }
      end
      let(:headers) { admin_headers }
    end

    describe 'permissions' do
      it_behaves_like 'permissions for list endpoint', ALL_PERMISSIONS do
        let(:api_call) { lambda { |user_headers| get '/v3/builds', nil, user_headers } }
        let(:org) { space.organization }
        let(:user) { VCAP::CloudController::User.make }

        let(:expected_codes_and_responses) do
          h = Hash.new(
            code: 200,
            response_guids: [build.guid, second_build.guid]
          )
          h['org_auditor'] = { code: 200, response_objects: [] }
          h['org_billing_manager'] = { code: 200, response_objects: [] }
          h['no_role'] = { code: 200, response_objects: [] }
          h
        end
      end
    end

    context 'when there are other spaces the developer cannot see' do
      let(:non_accessible_space) { VCAP::CloudController::Space.make }
      let(:non_accessible_app_model) { VCAP::CloudController::AppModel.make(space_guid: non_accessible_space.guid, name: 'other-app') }
      let!(:non_accessible_build) { VCAP::CloudController::BuildModel.make(app: non_accessible_app_model) }

      let(:per_page) { 2 }
      let(:order_by) { '-created_at' }

      it 'lists the builds for spaces that the user has access to' do
        get "v3/builds?order_by=#{order_by}&per_page=#{per_page}", nil, developer_headers

        parsed_response = MultiJson.load(last_response.body)

        expect(last_response.status).to eq(200)
        expect(parsed_response['resources']).to include(hash_including('guid' => build.guid))
        expect(parsed_response['resources']).to include(hash_including('guid' => second_build.guid))
        expect(parsed_response).to be_a_response_like({
          'pagination' => {
            'total_results' => 2,
            'total_pages' => 1,
            'first' => { 'href' => "#{link_prefix}/v3/builds?order_by=#{order_by}&page=1&per_page=2" },
            'last' => { 'href' => "#{link_prefix}/v3/builds?order_by=#{order_by}&page=1&per_page=2" },
            'next' => nil,
            'previous' => nil,
          },
          'resources' => [
            {
              'guid' => build.guid,
              'created_at' => iso8601,
              'updated_at' => iso8601,
              'state' => 'STAGED',
              'staging_memory_in_mb' => 123,
              'staging_disk_in_mb' => 456,
              'staging_log_rate_limit_bytes_per_second' => 234,
              'error' => nil,
              'lifecycle' => {
                'type' => 'buildpack',
                'data' => {
                  'buildpacks' => ['http://github.com/myorg/awesome-buildpack'],
                  'stack' => 'cflinuxfs4',
                },
              },
              'package' => { 'guid' => package.guid, },
              'droplet' => {
                'guid' => droplet.guid,
              },
              'relationships' => { 'app' => { 'data' => { 'guid' => app_model.guid } } },
              'metadata' => { 'labels' => {}, 'annotations' => {} },
              'links' => {
                'self' => { 'href' => "#{link_prefix}/v3/builds/#{build.guid}", },
                'app' => { 'href' => "#{link_prefix}/v3/apps/#{package.app.guid}", },
                'droplet' => { 'href' => "#{link_prefix}/v3/droplets/#{droplet.guid}", }
              },
              'created_by' => { 'guid' => developer.guid, 'name' => 'bob the builder', 'email' => 'bob@loblaw.com', }
            },
            {
              'guid' => second_build.guid,
              'created_at' => iso8601,
              'updated_at' => iso8601,
              'state' => 'STAGED',
              'staging_memory_in_mb' => 789,
              'staging_disk_in_mb' => 12,
              'staging_log_rate_limit_bytes_per_second' => 345,
              'error' => nil,
              'lifecycle' => {
                'type' => 'buildpack',
                'data' => {
                  'buildpacks' => ['http://github.com/myorg/awesome-buildpack'],
                  'stack' => 'cflinuxfs4',
                },
              },
              'package' => { 'guid' => second_package.guid, },
              'droplet' => {
                'guid' => second_droplet.guid,
              },
              'relationships' => { 'app' => { 'data' => { 'guid' => app_model.guid } } },
              'metadata' => { 'labels' => {}, 'annotations' => {} },
              'links' => {
                'self' => { 'href' => "#{link_prefix}/v3/builds/#{second_build.guid}", },
                'app' => { 'href' => "#{link_prefix}/v3/apps/#{package.app.guid}", },
                'droplet' => { 'href' => "#{link_prefix}/v3/droplets/#{second_droplet.guid}", }
              },
              'created_by' => { 'guid' => developer.guid, 'name' => 'bob the builder', 'email' => 'bob@loblaw.com', }
            },
          ]
        })
      end

      it 'filters on label_selector' do
        VCAP::CloudController::BuildLabelModel.make(key_name: 'fruit', value: 'strawberry', build: build)

        get '/v3/builds?label_selector=fruit=strawberry', {}, developer_headers

        expect(last_response.status).to eq(200)
        expect(parsed_response['resources'].count).to eq(1)
        expect(parsed_response['resources'][0]['guid']).to eq(build.guid)
      end

      it 'filters on package_guid' do
        get "/v3/builds?package_guids=#{second_package.guid}", {}, developer_headers

        expect(last_response.status).to eq(200)
        expect(parsed_response['resources'].count).to eq(1)
        expect(parsed_response['resources'][0]['guid']).to eq(second_build.guid)
      end

      it 'accepts 2 package guids' do
        get "/v3/builds?package_guids=#{package.guid},#{second_package.guid}", {}, developer_headers

        expect(last_response.status).to eq(200)
        expect(parsed_response['resources'].count).to eq(2)
        expect(parsed_response['resources'][0]['guid']).to eq(build.guid)
        expect(parsed_response['resources'][1]['guid']).to eq(second_build.guid)
      end
    end
  end

  describe 'GET /v3/builds/:guid' do
    let(:build) do
      VCAP::CloudController::BuildModel.make(
        package: package,
        app: app_model,
        staging_memory_in_mb: 123,
        staging_disk_in_mb: 456,
        staging_log_rate_limit: 789,
        created_by_user_name: 'bob the builder',
        created_by_user_guid: developer.guid,
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
    let(:body) do
      { lifecycle: { type: 'buildpack', data: { buildpacks: ['http://github.com/myorg/awesome-buildpack'],
        stack: 'cflinuxfs4' } } }
    end
    let(:staging_message) { VCAP::CloudController::BuildCreateMessage.new(body) }

    before do
      VCAP::CloudController::BuildpackLifecycle.new(package, staging_message).create_lifecycle_data_model(build)
      build.update(state: droplet.state, error_description: droplet.error_description)
    end

    it 'shows the build' do
      get "v3/builds/#{build.guid}", nil, developer_headers

      parsed_response = MultiJson.load(last_response.body)

      expected_response =
        {
          'guid' => build.guid,
          'created_at' => iso8601,
          'updated_at' => iso8601,
          'state' => 'STAGED',
          'staging_memory_in_mb' => 123,
          'staging_disk_in_mb' => 456,
          'staging_log_rate_limit_bytes_per_second' => 789,
          'error' => nil,
          'lifecycle' => {
            'type' => 'buildpack',
            'data' => {
              'buildpacks' => ['http://github.com/myorg/awesome-buildpack'],
              'stack' => 'cflinuxfs4',
            },
          },
          'package' => {
            'guid' => package.guid,
          },
          'droplet' => {
            'guid' => droplet.guid,
          },
          'metadata' => { 'labels' => {}, 'annotations' => {} },
          'relationships' => { 'app' => { 'data' => { 'guid' => app_model.guid } } },
          'links' => {
            'self' => {
              'href' => "#{link_prefix}/v3/builds/#{build.guid}",
            },
            'app' => {
              'href' => "#{link_prefix}/v3/apps/#{package.app.guid}",
            },
            'droplet' => {
              'href' => "#{link_prefix}/v3/droplets/#{droplet.guid}",
            }
          },
          'created_by' => {
            'guid' => developer.guid,
            'name' => 'bob the builder',
            'email' => 'bob@loblaw.com',
          }
        }

      expect(last_response.status).to eq(200)
      expect(parsed_response).to be_a_response_like(expected_response)
    end

    describe 'permissions' do
      it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS do
        let(:org) { space.organization }
        let(:user) { VCAP::CloudController::User.make }
        let(:api_call) { lambda { |user_headers| get "v3/builds/#{build.guid}", nil, user_headers } }

        let(:expected_codes_and_responses) do
          h = Hash.new(code: 200)
          h['org_auditor'] = { code: 404 }
          h['org_billing_manager'] = { code: 404 }
          h['no_role'] = { code: 404 }
          h
        end
      end
    end
  end

  describe 'PATCH /v3/builds/:guid' do
    let(:package_model) { VCAP::CloudController::PackageModel.make(app_guid: app_model.guid) }
    let(:build_model) { VCAP::CloudController::BuildModel.make(app: app_model, package: package_model) }
    let(:metadata) do
      {
        labels: {
          release: 'stable',
          'seriouseats.com/potato' => 'mashed'
        },
        annotations: { 'checksum' => 'SHA' },
      }
    end

    context 'when the build does not exist' do
      it 'returns a 404' do
        patch '/v3/builds/POTATO', { metadata: metadata }.to_json, developer_headers
        expect(last_response).to have_status_code(404)
      end
    end

    context 'the build exists' do
      context 'when the message is invalid' do
        let(:request) do
          {}
        end

        it 'returns 422 and renders the errors' do
          patch "/v3/builds/#{build_model.guid}", { state: 'NO_WAY' }.to_json, admin_headers
          expect(last_response).to have_status_code(422)
          expect(last_response.body).to include('UnprocessableEntity')
          expect(last_response.body).to include('not a valid state')
        end
      end

      it 'updates build metadata' do
        patch "/v3/builds/#{build_model.guid}", { metadata: metadata }.to_json, developer_headers
        expect(last_response.status).to eq(200), last_response.body

        expected_metadata = {
          'labels' => {
            'release' => 'stable',
            'seriouseats.com/potato' => 'mashed',
          },
          'annotations' => { 'checksum' => 'SHA' },
        }

        parsed_response = MultiJson.load(last_response.body)
        expect(parsed_response['metadata']).to eq(expected_metadata)
      end

      it 'cloud_controller returns 403 if not admin and not build_state_updater' do
        patch "/v3/builds/#{build_model.guid}", { metadata: metadata }.to_json, headers_for(make_auditor_for_space(space), user_name: user_name, email: 'bob@loblaw.com')
        expect(last_response.status).to eq(403), last_response.body
      end

      describe 'permissions' do
        let(:org) { space.organization }
        let(:user) { VCAP::CloudController::User.make }
        let(:api_call) { lambda { |user_headers| patch "/v3/builds/#{build_model.guid}", { metadata: metadata }.to_json, user_headers } }

        let(:expected_codes_and_responses) do
          h = Hash.new(code: 403, errors: CF_NOT_AUTHORIZED)
          h['admin'] = { code: 200 }
          h['org_auditor'] = { code: 404 }
          h['org_billing_manager'] = { code: 404 }
          h['no_role'] = { code: 404 }
          h['space_developer'] = { code: 200 }
          h
        end

        it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS

        context 'when organization is suspended' do
          let(:expected_codes_and_responses) do
            h = super()
            h['space_developer'] = { code: 403, errors: CF_ORG_SUSPENDED }
            h
          end

          before do
            org.update(status: VCAP::CloudController::Organization::SUSPENDED)
          end

          it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS
        end
      end

      context 'updating state' do
        let(:build_model) { VCAP::CloudController::BuildModel.make(:kpack, package: package_model,
          state: VCAP::CloudController::BuildModel::STAGING_STATE, app: app_model)
        }
        let(:request) do
          {
            state: 'STAGED',
            lifecycle: {
              type: 'kpack',
              data: {
                image: 'some-fake-image:tag',
              }
            }
          }
        end

        it 'allows admins to update the state' do
          patch "/v3/builds/#{build_model.guid}", request.to_json, admin_headers
          expect(last_response.status).to eq(200), last_response.body
          expect(build_model.reload.state).to eq('STAGED')
          parsed_response = MultiJson.load(last_response.body)
          expect(parsed_response['state']).to eq('STAGED')
        end

        context 'when the cloud_controller.update_build_state scope is present' do
          context 'when a build was successfully completed' do
            it 'updates the state to STAGED' do
              patch "/v3/builds/#{build_model.guid}", request.to_json, build_state_updater_headers
              parsed_response = MultiJson.load(last_response.body)
              expect(last_response.status).to eq(200)

              expect(build_model.reload.state).to eq('STAGED')
              expect(parsed_response['state']).to eq('STAGED')
            end

            it 'creates a droplet with the appropriate image reference' do
              patch "/v3/builds/#{build_model.guid}", request.to_json, build_state_updater_headers

              expect(build_model.reload.droplet.docker_receipt_image).to eq('some-fake-image:tag')
              expect(build_model.reload.droplet.state).to eq('STAGED')
            end
          end

          context 'when a build failed to complete' do
            let(:request) do
              {
                state: 'FAILED',
                error: 'failed to stage build'
              }
            end

            it 'returns 200' do
              patch "/v3/builds/#{build_model.guid}", request.to_json, build_state_updater_headers
              expect(last_response.status).to eq(200), last_response.body
            end
          end
        end

        context 'when the cloud_controller.update_build_state scope is NOT present' do
          it '403s' do
            patch "/v3/builds/#{build_model.guid}", { state: 'STAGED' }.to_json, developer_headers
            expect(last_response.status).to eq(403), last_response.body
          end
        end

        context 'when the the developer is looking in the wrong space' do
          let(:wrong_developer) { make_developer_for_space(VCAP::CloudController::Space.make) }
          let(:wrong_developer_headers) { headers_for(wrong_developer, user_name: user_name, email: 'bob@loblaw.com') }

          it '404s' do
            patch "/v3/builds/#{build_model.guid}", { state: 'STAGED' }.to_json, wrong_developer_headers
            expect(last_response.status).to eq(404), last_response.body
          end
        end
      end
    end
  end
end
