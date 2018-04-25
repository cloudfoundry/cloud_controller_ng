require 'spec_helper'

RSpec.describe 'Builds' do
  let(:bbs_stager_client) { instance_double(VCAP::CloudController::Diego::BbsStagerClient) }
  let(:space) { VCAP::CloudController::Space.make }
  let(:developer) { make_developer_for_space(space) }
  let(:developer_headers) { headers_for(developer, user_name: user_name, email: 'bob@loblaw.com') }
  let(:user_name) { 'bob the builder' }
  let(:parsed_response) { MultiJson.load(last_response.body) }
  let(:app_model) { VCAP::CloudController::AppModel.make(space_guid: space.guid, name: 'my-app') }

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
            stack: 'cflinuxfs2'
          },
        },
        package: {
          guid: package.guid
        }
      }
    end

    before do
      stack = (VCAP::CloudController::Stack.find(name: create_request[:lifecycle][:data][:stack]) ||
               VCAP::CloudController::Stack.make(name: create_request[:lifecycle][:data][:stack]))
      # putting stack in the App.make call leads to an "App doesn't have a primary key" error
      # message from sequel.
      process = VCAP::CloudController::ProcessModel.make(app: app_model, memory: 1024, disk_quota: 1536)
      process.stack = stack
      process.save
      allow_any_instance_of(CloudController::Blobstore::UrlGenerator).to receive(:package_download_url).and_return('some-string')
      allow_any_instance_of(CloudController::Blobstore::UrlGenerator).to receive(:package_droplet_upload_url).and_return('some-string')
      CloudController::DependencyLocator.instance.register(:bbs_stager_client, bbs_stager_client)
      allow(bbs_stager_client).to receive(:stage)
    end

    it 'creates a Builds resource' do
      post '/v3/builds', create_request.to_json, developer_headers

      created_build = VCAP::CloudController::BuildModel.last

      expected_response =
        {
          'guid' => created_build.guid,
          'created_at' => iso8601,
          'updated_at' => iso8601,
          'state' => 'STAGING',
          'error' => nil,
          'lifecycle' => {
            'type' => 'buildpack',
            'data' => {
              'buildpacks' => ['http://github.com/myorg/awesome-buildpack'],
              'stack' => 'cflinuxfs2'
            },
          },
          'package' => {
            'guid' => package.guid
          },
          'droplet' => nil,
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
  end

  describe 'GET /v3/builds' do
    let(:build) do
      VCAP::CloudController::BuildModel.make(
        package: package,
        app: app_model,
        created_by_user_name: 'bob the builder',
        created_by_user_guid: developer.guid,
        created_by_user_email: 'bob@loblaw.com'
      )
    end
    let!(:second_build) do
      VCAP::CloudController::BuildModel.make(
        package: package,
        app: app_model,
        created_at: build.created_at - 1.day,
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
    let(:second_droplet) { VCAP::CloudController::DropletModel.make(
      state: VCAP::CloudController::DropletModel::STAGED_STATE,
      package_guid: package.guid,
      build: second_build,
    )
    }
    let(:body) do
      { lifecycle: { type: 'buildpack', data: { buildpacks: ['http://github.com/myorg/awesome-buildpack'],
                                                stack: 'cflinuxfs2' } } }
    end
    let(:staging_message) { VCAP::CloudController::BuildCreateMessage.new(body) }

    before do
      VCAP::CloudController::BuildpackLifecycle.new(package, staging_message).create_lifecycle_data_model(build)
      VCAP::CloudController::BuildpackLifecycle.new(package, staging_message).create_lifecycle_data_model(second_build)
      build.update(state: droplet.state, error_description: droplet.error_description)
      second_build.update(state: second_droplet.state, error_description: second_droplet.error_description)
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
            'total_pages'   => 1,
            'first'         => { 'href' => "#{link_prefix}/v3/builds?order_by=#{order_by}&page=1&per_page=2" },
            'last'          => { 'href' => "#{link_prefix}/v3/builds?order_by=#{order_by}&page=1&per_page=2" },
            'next'          => nil,
            'previous'      => nil,
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
                  'stack' => 'cflinuxfs2',
                },
              },
              'package' => { 'guid' => package.guid, },
              'droplet' => {
                'guid' => droplet.guid,
                'href' => "#{link_prefix}/v3/droplets/#{droplet.guid}",
              },
              'links' => {
                'self' => { 'href' => "#{link_prefix}/v3/builds/#{build.guid}", },
                'app' => { 'href' => "#{link_prefix}/v3/apps/#{package.app.guid}", }
              },
              'created_by' => { 'guid' => developer.guid, 'name' => 'bob the builder', 'email' => 'bob@loblaw.com', }
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
                  'stack' => 'cflinuxfs2',
                },
              },
              'package' => { 'guid' => package.guid, },
              'droplet' => {
                'guid' => second_droplet.guid,
                'href' => "#{link_prefix}/v3/droplets/#{second_droplet.guid}",
              },
              'links' => {
                'self' => { 'href' => "#{link_prefix}/v3/builds/#{second_build.guid}", },
                'app' => { 'href' => "#{link_prefix}/v3/apps/#{package.app.guid}", }
              },
              'created_by' => { 'guid' => developer.guid, 'name' => 'bob the builder', 'email' => 'bob@loblaw.com', }
            },
          ]
        })
      end
    end
  end

  describe 'GET /v3/builds/:guid' do
    let(:build) do
      VCAP::CloudController::BuildModel.make(
        package: package,
        app: app_model,
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
                                                stack: 'cflinuxfs2' } } }
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
          'error' => nil,
          'lifecycle' => {
            'type' => 'buildpack',
            'data' => {
              'buildpacks' => ['http://github.com/myorg/awesome-buildpack'],
              'stack' => 'cflinuxfs2',
            },
          },
          'package' => {
            'guid' => package.guid,
          },
          'droplet' => {
            'guid' => droplet.guid,
            'href' => "#{link_prefix}/v3/droplets/#{droplet.guid}",
          },
          'links' => {
            'self' => {
              'href' => "#{link_prefix}/v3/builds/#{build.guid}",
            },
            'app' => {
              'href' => "#{link_prefix}/v3/apps/#{package.app.guid}",
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
  end
end
