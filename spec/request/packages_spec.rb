require 'spec_helper'

RSpec.describe 'Packages' do
  let(:email) { 'potato@house.com' }
  let(:user) { VCAP::CloudController::User.make }
  let(:user_header) { headers_for(user, email: email) }
  let(:space) { VCAP::CloudController::Space.make }
  let(:space_guid) { space.guid }
  let(:app_model) { VCAP::CloudController::AppModel.make(space_guid: space_guid) }

  describe 'POST /v3/apps/:guid/packages' do
    let(:guid) { app_model.guid }

    before do
      space.organization.add_user(user)
      space.add_developer(user)
    end

    let(:type) { 'docker' }
    let(:data) do
      {
        image: 'registry/image:latest'
      }
    end

    describe 'creation' do
      it 'creates a package' do
        expect {
          post "/v3/apps/#{guid}/packages", { type: type, data: data }, user_header
        }.to change { VCAP::CloudController::PackageModel.count }.by(1)

        package = VCAP::CloudController::PackageModel.last

        expected_response = {
          'guid'       => package.guid,
          'type'       => type,
          'data'       => {
            'image'    => 'registry/image:latest',
          },
          'state'      => 'READY',
          'created_at' => iso8601,
          'updated_at' => nil,
          'links' => {
            'self' => { 'href' => "/v3/packages/#{package.guid}" },
            'app'  => { 'href' => "/v3/apps/#{guid}" },
            'stage' => { 'href' => "/v3/packages/#{package.guid}/droplets", 'method' => 'POST' },
          }
        }

        expected_metadata = {
          package_guid: package.guid,
          request: {
            type: type,
            data: data
          }
        }.to_json

        parsed_response = MultiJson.load(last_response.body)
        expect(last_response.status).to eq(201)
        expect(parsed_response).to be_a_response_like(expected_response)

        event = VCAP::CloudController::Event.last
        expect(event.values).to include({
          type:              'audit.app.package.create',
          actor:             user.guid,
          actor_type:        'user',
          actor_name:        email,
          actee:             package.app.guid,
          actee_type:        'v3-app',
          actee_name:        package.app.name,
          metadata:          expected_metadata,
          space_guid:        space.guid,
          organization_guid: space.organization.guid
        })
      end
    end

    describe 'copying' do
      let(:target_app_model) { VCAP::CloudController::AppModel.make(space_guid: space_guid) }
      let!(:original_package) { VCAP::CloudController::PackageModel.make(type: 'docker', app_guid: app_model.guid) }
      let!(:guid) { target_app_model.guid }
      let(:source_package_guid) { original_package.guid }

      before do
        VCAP::CloudController::PackageDockerDataModel.create(package: original_package, image: 'http://awesome-sauce.com')
      end

      it 'copies a package' do
        expect {
          post "/v3/apps/#{guid}/packages?source_package_guid=#{source_package_guid}", {}, user_header
        }.to change { VCAP::CloudController::PackageModel.count }.by(1)

        package = VCAP::CloudController::PackageModel.last

        expected_response = {
          'guid'       => package.guid,
          'type'       => 'docker',
          'data'       => {
            'image'    => 'http://awesome-sauce.com'
          },
          'state'      => 'READY',
          'created_at' => iso8601,
          'updated_at' => nil,
          'links' => {
            'self' => { 'href' => "/v3/packages/#{package.guid}" },
            'app'  => { 'href' => "/v3/apps/#{guid}" },
            'stage' => { 'href' => "/v3/packages/#{package.guid}/droplets", 'method' => 'POST' },
          }
        }

        expect(last_response.status).to eq(201)
        parsed_response = MultiJson.load(last_response.body)
        expect(parsed_response).to be_a_response_like(expected_response)

        expected_metadata = {
          package_guid: package.guid,
          request: {
            source_package_guid: source_package_guid
          }
        }.to_json

        event = VCAP::CloudController::Event.last
        expect(event.values).to include({
          type:              'audit.app.package.create',
          actor:             user.guid,
          actor_type:        'user',
          actor_name:        email,
          actee:             package.app.guid,
          actee_type:        'v3-app',
          actee_name:        package.app.name,
          metadata:          expected_metadata,
          space_guid:        space.guid,
          organization_guid: space.organization.guid
        })
      end
    end
  end

  describe 'GET /v3/apps/:guid/packages' do
    let(:space) { VCAP::CloudController::Space.make }
    let!(:package) { VCAP::CloudController::PackageModel.make(app_guid: app_model.guid, created_at: Time.at(1)) }
    let(:app_model) { VCAP::CloudController::AppModel.make(space_guid: space.guid) }
    let(:guid) { app_model.guid }
    let(:page) { 1 }
    let(:per_page) { 2 }
    let(:order_by) { '-created_at' }

    before do
      space.organization.add_user(user)
      space.add_developer(user)
    end

    it 'lists paginated result of all packages for an app' do
      package2 = VCAP::CloudController::PackageModel.make(app_guid: app_model.guid, created_at: Time.at(2))

      expected_response = {
        'pagination' => {
          'total_results' => 2,
          'total_pages'   => 1,
          'first'         => { 'href' => "/v3/apps/#{guid}/packages?order_by=-created_at&page=1&per_page=2" },
          'last'          => { 'href' => "/v3/apps/#{guid}/packages?order_by=-created_at&page=1&per_page=2" },
          'next'          => nil,
          'previous'      => nil,
        },
        'resources' => [
          {
            'guid'       => package2.guid,
            'type'       => 'bits',
            'data'       => {
              'hash'       => { 'type' => 'sha1', 'value' => nil },
              'error'      => nil
            },
            'state'      => VCAP::CloudController::PackageModel::CREATED_STATE,
            'created_at' => iso8601,
            'updated_at' => nil,
            'links' => {
              'self'   => { 'href' => "/v3/packages/#{package2.guid}" },
              'upload' => { 'href' => "/v3/packages/#{package2.guid}/upload", 'method' => 'POST' },
              'download' => { 'href' => "/v3/packages/#{package2.guid}/download", 'method' => 'GET' },
              'stage' => { 'href' => "/v3/packages/#{package2.guid}/droplets", 'method' => 'POST' },
              'app' => { 'href' => "/v3/apps/#{guid}" },
            }
          },
          {
            'guid'       => package.guid,
            'type'       => 'bits',
            'data'       => {
              'hash'       => { 'type' => 'sha1', 'value' => nil },
              'error'      => nil
            },
            'state'      => VCAP::CloudController::PackageModel::CREATED_STATE,
            'created_at' => iso8601,
            'updated_at' => nil,
            'links' => {
              'self'   => { 'href' => "/v3/packages/#{package.guid}" },
              'upload' => { 'href' => "/v3/packages/#{package.guid}/upload", 'method' => 'POST' },
              'download' => { 'href' => "/v3/packages/#{package.guid}/download", 'method' => 'GET' },
              'stage' => { 'href' => "/v3/packages/#{package.guid}/droplets", 'method' => 'POST' },
              'app' => { 'href' => "/v3/apps/#{guid}" },
            }
          },
        ]
      }

      get "/v3/apps/#{guid}/packages?page=#{page}&per_page=#{per_page}&order_by=#{order_by}", {}, user_header

      parsed_response = MultiJson.load(last_response.body)

      expect(last_response.status).to eq(200)
      expect(parsed_response).to be_a_response_like(expected_response)
    end

    context 'faceted search' do
      it 'filters by types' do
        VCAP::CloudController::PackageModel.make(app_guid: app_model.guid, type: VCAP::CloudController::PackageModel::BITS_TYPE)
        VCAP::CloudController::PackageModel.make(app_guid: app_model.guid, type: VCAP::CloudController::PackageModel::BITS_TYPE)
        VCAP::CloudController::PackageModel.make(app_guid: app_model.guid, type: VCAP::CloudController::PackageModel::DOCKER_TYPE)
        VCAP::CloudController::PackageModel.make(type: VCAP::CloudController::PackageModel::BITS_TYPE)

        get '/v3/packages?types=bits', {}, user_header

        expected_pagination = {
          'total_results' => 3,
          'total_pages'   => 1,
          'first'         => { 'href' => '/v3/packages?page=1&per_page=50&types=bits' },
          'last'          => { 'href' => '/v3/packages?page=1&per_page=50&types=bits' },
          'next'          => nil,
          'previous'      => nil
        }

        parsed_response = MultiJson.load(last_response.body)

        expect(last_response.status).to eq(200)
        expect(parsed_response['resources'].count).to eq(3)
        expect(parsed_response['resources'].map { |r| r['type'] }.uniq).to eq(['bits'])
        expect(parsed_response['pagination']).to eq(expected_pagination)
      end

      it 'filters by states' do
        VCAP::CloudController::PackageModel.make(app_guid: app_model.guid, state: VCAP::CloudController::PackageModel::PENDING_STATE)
        VCAP::CloudController::PackageModel.make(app_guid: app_model.guid, state: VCAP::CloudController::PackageModel::PENDING_STATE)
        VCAP::CloudController::PackageModel.make(app_guid: app_model.guid, state: VCAP::CloudController::PackageModel::READY_STATE)
        VCAP::CloudController::PackageModel.make(state: VCAP::CloudController::PackageModel::PENDING_STATE)

        get "/v3/apps/#{app_model.guid}/packages?states=PROCESSING_UPLOAD", {}, user_header

        expected_pagination = {
          'total_results' => 2,
          'total_pages'   => 1,
          'first'         => { 'href' => "/v3/apps/#{app_model.guid}/packages?page=1&per_page=50&states=PROCESSING_UPLOAD" },
          'last'          => { 'href' => "/v3/apps/#{app_model.guid}/packages?page=1&per_page=50&states=PROCESSING_UPLOAD" },
          'next'          => nil,
          'previous'      => nil
        }

        parsed_response = MultiJson.load(last_response.body)

        expect(last_response.status).to eq(200)
        expect(parsed_response['resources'].count).to eq(2)
        expect(parsed_response['resources'].map { |r| r['state'] }.uniq).to eq(['PROCESSING_UPLOAD'])
        expect(parsed_response['pagination']).to eq(expected_pagination)
      end

      it 'filters by package guids' do
        package1 = VCAP::CloudController::PackageModel.make(app_guid: app_model.guid)
        package2 = VCAP::CloudController::PackageModel.make(app_guid: app_model.guid)
        VCAP::CloudController::PackageModel.make

        get "/v3/apps/#{app_model.guid}/packages?guids=#{package1.guid},#{package2.guid}", {}, user_header

        expected_pagination = {
          'total_results' => 2,
          'total_pages'   => 1,
          'first'         => { 'href' => "/v3/apps/#{app_model.guid}/packages?guids=#{package1.guid}%2C#{package2.guid}&page=1&per_page=50" },
          'last'          => { 'href' => "/v3/apps/#{app_model.guid}/packages?guids=#{package1.guid}%2C#{package2.guid}&page=1&per_page=50" },
          'next'          => nil,
          'previous'      => nil
        }

        parsed_response = MultiJson.load(last_response.body)

        expect(last_response.status).to eq(200)
        expect(parsed_response['resources'].map { |r| r['guid'] }).to match_array([package1.guid, package2.guid])
        expect(parsed_response['pagination']).to eq(expected_pagination)
      end
    end
  end

  describe 'GET /v3/packages' do
    let(:bits_type) { 'bits' }
    let(:docker_type) { 'docker' }
    let(:page) { 1 }
    let(:per_page) { 2 }

    before do
      space.organization.add_user(user)
      space.add_developer(user)
    end

    it 'gets all the packages' do
      bits_package = VCAP::CloudController::PackageModel.make(type: bits_type, app_guid: app_model.guid)
      docker_package = VCAP::CloudController::PackageModel.make(
        type: docker_type,
        app_guid: app_model.guid,
        state: VCAP::CloudController::PackageModel::READY_STATE)
      docker_package2 = VCAP::CloudController::PackageModel.make(type: docker_type, app_guid: app_model.guid)
      VCAP::CloudController::PackageModel.make(app_guid: VCAP::CloudController::AppModel.make.guid)
      VCAP::CloudController::PackageDockerDataModel.create(package: docker_package, image: 'http://location-of-image.com')
      VCAP::CloudController::PackageDockerDataModel.create(package: docker_package2, image: 'http://location-of-image-2.com')

      expected_response =
        {
        'pagination' => {
              'total_results' => 3,
              'total_pages'   => 2,
              'first'         => { 'href' => '/v3/packages?page=1&per_page=2' },
              'last'          => { 'href' => '/v3/packages?page=2&per_page=2' },
              'next'          => { 'href' => '/v3/packages?page=2&per_page=2' },
              'previous'      => nil,
            },
        'resources' => [
          {
            'guid'       => bits_package.guid,
            'type'       => 'bits',
            'data'       => {
              'hash'       => { 'type' => 'sha1', 'value' => nil },
              'error'      => nil
            },
            'state'      => VCAP::CloudController::PackageModel::CREATED_STATE,
            'created_at' => iso8601,
            'updated_at' => nil,
            'links' => {
              'self'   => { 'href' => "/v3/packages/#{bits_package.guid}" },
              'upload' => { 'href' => "/v3/packages/#{bits_package.guid}/upload", 'method' => 'POST' },
              'download' => { 'href' => "/v3/packages/#{bits_package.guid}/download", 'method' => 'GET' },
              'stage' => { 'href' => "/v3/packages/#{bits_package.guid}/droplets", 'method' => 'POST' },
              'app' => { 'href' => "/v3/apps/#{bits_package.app_guid}" },
            }
          },
          {
            'guid'       => docker_package.guid,
            'type'       => 'docker',
            'data'       => {
              'image'    => 'http://location-of-image.com'
            },
            'state'      => VCAP::CloudController::PackageModel::READY_STATE,
            'created_at' => iso8601,
            'updated_at' => nil,
            'links' => {
              'self' => { 'href' => "/v3/packages/#{docker_package.guid}" },
              'app'  => { 'href' => "/v3/apps/#{docker_package.app_guid}" },
              'stage' => { 'href' => "/v3/packages/#{docker_package.guid}/droplets", 'method' => 'POST' },
            }
          }
        ]
        }

      get '/v3/packages', { per_page: per_page }, user_header

      parsed_response = MultiJson.load(last_response.body)
      expect(last_response.status).to eq(200)
      expect(parsed_response).to be_a_response_like(expected_response)
    end

    context 'faceted search' do
      it 'filters by types' do
        VCAP::CloudController::PackageModel.make(app_guid: app_model.guid, type: VCAP::CloudController::PackageModel::BITS_TYPE)
        VCAP::CloudController::PackageModel.make(app_guid: app_model.guid, type: VCAP::CloudController::PackageModel::BITS_TYPE)
        VCAP::CloudController::PackageModel.make(app_guid: app_model.guid, type: VCAP::CloudController::PackageModel::DOCKER_TYPE)

        another_app_in_same_space = VCAP::CloudController::AppModel.make(space_guid: space_guid)
        VCAP::CloudController::PackageModel.make(app_guid: another_app_in_same_space.guid, type: VCAP::CloudController::PackageModel::BITS_TYPE)

        get '/v3/packages?types=bits', {}, user_header

        expected_pagination = {
          'total_results' => 3,
          'total_pages'   => 1,
          'first'         => { 'href' => '/v3/packages?page=1&per_page=50&types=bits' },
          'last'          => { 'href' => '/v3/packages?page=1&per_page=50&types=bits' },
          'next'          => nil,
          'previous'      => nil
        }

        parsed_response = MultiJson.load(last_response.body)

        expect(last_response.status).to eq(200)
        expect(parsed_response['resources'].count).to eq(3)
        expect(parsed_response['resources'].map { |r| r['type'] }.uniq).to eq(['bits'])
        expect(parsed_response['pagination']).to eq(expected_pagination)
      end

      it 'filters by states' do
        VCAP::CloudController::PackageModel.make(app_guid: app_model.guid, state: VCAP::CloudController::PackageModel::PENDING_STATE)
        VCAP::CloudController::PackageModel.make(app_guid: app_model.guid, state: VCAP::CloudController::PackageModel::PENDING_STATE)
        VCAP::CloudController::PackageModel.make(app_guid: app_model.guid, state: VCAP::CloudController::PackageModel::READY_STATE)

        another_app_in_same_space = VCAP::CloudController::AppModel.make(space_guid: space_guid)
        VCAP::CloudController::PackageModel.make(app_guid: another_app_in_same_space.guid, state: VCAP::CloudController::PackageModel::PENDING_STATE)

        get '/v3/packages?states=PROCESSING_UPLOAD', {}, user_header

        expected_pagination = {
          'total_results' => 3,
          'total_pages'   => 1,
          'first'         => { 'href' => '/v3/packages?page=1&per_page=50&states=PROCESSING_UPLOAD' },
          'last'          => { 'href' => '/v3/packages?page=1&per_page=50&states=PROCESSING_UPLOAD' },
          'next'          => nil,
          'previous'      => nil
        }

        parsed_response = MultiJson.load(last_response.body)

        expect(last_response.status).to eq(200)
        expect(parsed_response['resources'].count).to eq(3)
        expect(parsed_response['resources'].map { |r| r['state'] }.uniq).to eq(['PROCESSING_UPLOAD'])
        expect(parsed_response['pagination']).to eq(expected_pagination)
      end

      it 'filters by app guids' do
        app_model2 = VCAP::CloudController::AppModel.make(space_guid: space_guid)
        package1 = VCAP::CloudController::PackageModel.make(app_guid: app_model.guid)
        package2 = VCAP::CloudController::PackageModel.make(app_guid: app_model2.guid)
        VCAP::CloudController::PackageModel.make

        get "/v3/packages?app_guids=#{app_model.guid},#{app_model2.guid}", {}, user_header

        expected_pagination = {
          'total_results' => 2,
          'total_pages'   => 1,
          'first'         => { 'href' => "/v3/packages?app_guids=#{app_model.guid}%2C#{app_model2.guid}&page=1&per_page=50" },
          'last'          => { 'href' => "/v3/packages?app_guids=#{app_model.guid}%2C#{app_model2.guid}&page=1&per_page=50" },
          'next'          => nil,
          'previous'      => nil
        }

        parsed_response = MultiJson.load(last_response.body)

        expect(last_response.status).to eq(200)
        expect(parsed_response['resources'].map { |r| r['guid'] }).to match_array([package1.guid, package2.guid])
        expect(parsed_response['pagination']).to eq(expected_pagination)
      end

      it 'filters by package guids' do
        app_model2 = VCAP::CloudController::AppModel.make(space_guid: space_guid)
        package1 = VCAP::CloudController::PackageModel.make(app_guid: app_model2.guid)
        package2 = VCAP::CloudController::PackageModel.make(app_guid: app_model2.guid)
        VCAP::CloudController::PackageModel.make

        get "/v3/packages?guids=#{package1.guid},#{package2.guid}", {}, user_header

        expected_pagination = {
          'total_results' => 2,
          'total_pages'   => 1,
          'first'         => { 'href' => "/v3/packages?guids=#{package1.guid}%2C#{package2.guid}&page=1&per_page=50" },
          'last'          => { 'href' => "/v3/packages?guids=#{package1.guid}%2C#{package2.guid}&page=1&per_page=50" },
          'next'          => nil,
          'previous'      => nil
        }

        parsed_response = MultiJson.load(last_response.body)

        expect(last_response.status).to eq(200)
        expect(parsed_response['resources'].map { |r| r['guid'] }).to match_array([package1.guid, package2.guid])
        expect(parsed_response['pagination']).to eq(expected_pagination)
      end

      it 'filters by space guids' do
        package_on_space1 = VCAP::CloudController::PackageModel.make(app_guid: app_model.guid)

        space2 = VCAP::CloudController::Space.make(organization: space.organization)
        space2.add_developer(user)
        app_model2 = VCAP::CloudController::AppModel.make(space_guid: space2.guid)
        package_on_space2 = VCAP::CloudController::PackageModel.make(app_guid: app_model2.guid)

        space3 = VCAP::CloudController::Space.make(organization: space.organization)
        space3.add_developer(user)
        app_model3 = VCAP::CloudController::AppModel.make(space_guid: space3.guid)
        VCAP::CloudController::PackageModel.make(app_guid: app_model3.guid)

        get "/v3/packages?space_guids=#{space2.guid},#{space_guid}", {}, user_header

        expected_pagination = {
          'total_results' => 2,
          'total_pages'   => 1,
          'first'         => { 'href' => "/v3/packages?page=1&per_page=50&space_guids=#{space2.guid}%2C#{space_guid}" },
          'last'          => { 'href' => "/v3/packages?page=1&per_page=50&space_guids=#{space2.guid}%2C#{space_guid}" },
          'next'          => nil,
          'previous'      => nil
        }

        parsed_response = MultiJson.load(last_response.body)

        expect(last_response.status).to eq(200)
        expect(parsed_response['resources'].map { |r| r['guid'] }).to match_array([package_on_space2.guid, package_on_space1.guid])
        expect(parsed_response['pagination']).to eq(expected_pagination)
      end

      it 'filters by org guids' do
        org1_guid = space.organization.guid

        package_in_org1 = VCAP::CloudController::PackageModel.make(app_guid: app_model.guid)

        space2 = VCAP::CloudController::Space.make
        org2_guid = space2.organization.guid
        app_model2 = VCAP::CloudController::AppModel.make(space_guid: space2.guid)

        space2.organization.add_user(user)
        space2.add_developer(user)

        package_in_org2 = VCAP::CloudController::PackageModel.make(app_guid: app_model2.guid)

        space3 = VCAP::CloudController::Space.make
        space3.organization.add_user(user)
        space3.add_developer(user)
        app_model3 = VCAP::CloudController::AppModel.make(space_guid: space3.guid)
        VCAP::CloudController::PackageModel.make(app_guid: app_model3.guid)

        get "/v3/packages?organization_guids=#{org1_guid},#{org2_guid}", {}, user_header

        expected_pagination = {
          'total_results' => 2,
          'total_pages'   => 1,
          'first'         => { 'href' => "/v3/packages?organization_guids=#{org1_guid}%2C#{org2_guid}&page=1&per_page=50" },
          'last'          => { 'href' => "/v3/packages?organization_guids=#{org1_guid}%2C#{org2_guid}&page=1&per_page=50" },
          'next'          => nil,
          'previous'      => nil
        }

        parsed_response = MultiJson.load(last_response.body)

        expect(last_response.status).to eq(200)
        expect(parsed_response['resources'].map { |r| r['guid'] }).to match_array([package_in_org1.guid, package_in_org2.guid])
        expect(parsed_response['pagination']).to eq(expected_pagination)
      end
    end
  end

  describe 'GET /v3/packages/:guid' do
    let(:space) { VCAP::CloudController::Space.make }
    let(:app_model) { VCAP::CloudController::AppModel.make(space_guid: space.guid) }
    let(:package_model) do
      VCAP::CloudController::PackageModel.make(app_guid: app_model.guid)
    end

    let(:guid) { package_model.guid }
    let(:space_guid) { space.guid }

    before do
      space.organization.add_user user
      space.add_developer user
    end

    it 'gets a package' do
      expected_response = {
        'type'       => package_model.type,
        'guid'       => guid,
        'data'       => {
          'hash'       => { 'type' => 'sha1', 'value' => nil },
          'error'      => nil
        },
        'state'      => VCAP::CloudController::PackageModel::CREATED_STATE,
        'created_at' => iso8601,
        'updated_at' => nil,
        'links' => {
          'self'   => { 'href' => "/v3/packages/#{guid}" },
          'upload' => { 'href' => "/v3/packages/#{guid}/upload", 'method' => 'POST' },
          'download' => { 'href' => "/v3/packages/#{guid}/download", 'method' => 'GET' },
          'stage' => { 'href' => "/v3/packages/#{guid}/droplets", 'method' => 'POST' },
          'app' => { 'href' => "/v3/apps/#{app_model.guid}" },
        }
      }

      get "v3/packages/#{guid}", {}, user_header

      parsed_response = MultiJson.load(last_response.body)
      expect(last_response.status).to eq(200)
      expect(parsed_response).to be_a_response_like(expected_response)
    end
  end

  describe 'POST /v3/packages/:guid/upload' do
    let(:type) { 'bits' }
    let!(:package_model) do
      VCAP::CloudController::PackageModel.make(app_guid: app_model.guid, type: type)
    end
    let(:space) { VCAP::CloudController::Space.make }
    let(:app_model) { VCAP::CloudController::AppModel.make(guid: 'woof', space_guid: space.guid, name: 'meow') }
    let(:guid) { package_model.guid }
    let(:tmpdir) { Dir.mktmpdir }

    before do
      space.organization.add_user(user)
      space.add_developer(user)
    end

    let(:packages_params) do
      {
        bits_name: 'application.zip',
        bits_path: "#{tmpdir}/application.zip",
      }
    end

    it 'uploads the bits for the package' do
      expect(Delayed::Job.count).to eq 0

      post "/v3/packages/#{guid}/upload", packages_params, user_header

      expect(Delayed::Job.count).to eq 1

      expected_response = {
        'type'       => package_model.type,
        'guid'       => guid,
        'data'       => {
          'hash'       => { 'type' => 'sha1', 'value' => nil },
          'error'      => nil
        },
        'state'      => VCAP::CloudController::PackageModel::PENDING_STATE,
        'created_at' => iso8601,
        'updated_at' => iso8601,
        'links' => {
          'self'   => { 'href' => "/v3/packages/#{guid}" },
          'upload' => { 'href' => "/v3/packages/#{guid}/upload", 'method' => 'POST' },
          'download' => { 'href' => "/v3/packages/#{guid}/download", 'method' => 'GET' },
          'stage' => { 'href' => "/v3/packages/#{guid}/droplets", 'method' => 'POST' },
          'app' => { 'href' => "/v3/apps/#{app_model.guid}" },
        }
      }
      parsed_response = MultiJson.load(last_response.body)
      expect(last_response.status).to eq(200)
      expect(parsed_response).to be_a_response_like(expected_response)

      expected_metadata = { package_guid: package_model.guid }.to_json

      event = VCAP::CloudController::Event.last
      expect(event.values).to include({
        type:              'audit.app.package.upload',
        actor:             user.guid,
        actor_type:        'user',
        actor_name:        email,
        actee:             'woof',
        actee_type:        'v3-app',
        actee_name:        'meow',
        metadata:          expected_metadata,
        space_guid:        space.guid,
        organization_guid: space.organization.guid
      })
    end
  end

  describe 'GET /v3/packages/:guid/download' do
    let(:type) { 'bits' }
    let!(:package_model) do
      VCAP::CloudController::PackageModel.make(app_guid: app_model.guid, type: type)
    end
    let(:app_model) do
      VCAP::CloudController::AppModel.make(guid: 'woof-guid', space_guid: space.guid, name: 'meow')
    end
    let(:space) { VCAP::CloudController::Space.make }
    let(:bits_download_url) { CloudController::DependencyLocator.instance.blobstore_url_generator.package_download_url(package_model) }
    let(:guid) { package_model.guid }
    let(:temp_file) do
      file = File.join(Dir.mktmpdir, 'application.zip')
      TestZip.create(file, 1, 1024)
      file
    end
    let(:upload_body) do
      {
        bits_name: 'application.zip',
        bits_path: temp_file,
      }
    end

    before do
      space.organization.add_user(user)
      space.add_developer(user)
      post "/v3/packages/#{guid}/upload", upload_body, user_header
      Delayed::Worker.new.work_off
    end

    it 'downloads the bit(s) for a package' do
      Timecop.freeze do
        get "/v3/packages/#{guid}/download", {}, user_header

        expect(last_response.status).to eq(302)
        expect(last_response.headers['Location']).to eq(bits_download_url)

        expected_metadata = { package_guid: package_model.guid }.to_json

        event = VCAP::CloudController::Event.last
        expect(event.values).to include({
          type:              'audit.app.package.download',
          actor:             user.guid,
          actor_type:        'user',
          actor_name:        email,
          actee:             'woof-guid',
          actee_type:        'v3-app',
          actee_name:        'meow',
          metadata:          expected_metadata,
          space_guid:        space.guid,
          organization_guid: space.organization.guid
        })
      end
    end
  end

  describe 'DELETE /v3/packages/:guid' do
    let(:app_name) { 'sir meow' }
    let(:app_guid) { 'meow-the-guid' }
    let(:space) { VCAP::CloudController::Space.make }
    let(:app_model) { VCAP::CloudController::AppModel.make(space_guid: space.guid, name: app_name, guid: app_guid) }
    let!(:package_model) do
      VCAP::CloudController::PackageModel.make(app_guid: app_model.guid)
    end

    let(:guid) { package_model.guid }

    before do
      space.organization.add_user user
      space.add_developer user
    end

    it 'deletes a package' do
      expect {
        delete "/v3/packages/#{guid}", {}, user_header
      }.to change { VCAP::CloudController::PackageModel.count }.by(-1)
      expect(last_response.status).to eq(204)

      expected_metadata = { package_guid: guid }.to_json

      event = VCAP::CloudController::Event.last
      expect(event.values).to include({
        type:              'audit.app.package.delete',
        actor:             user.guid,
        actor_type:        'user',
        actor_name:        email,
        actee:             app_guid,
        actee_type:        'v3-app',
        actee_name:        app_name,
        metadata:          expected_metadata,
        space_guid:        space.guid,
        organization_guid: space.organization.guid
      })
    end
  end
end
