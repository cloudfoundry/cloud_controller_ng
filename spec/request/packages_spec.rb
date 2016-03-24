ENV['RACK_ENV'] = 'test'
require 'rack/test'
require 'spec_helper'


# require 'rails_helper'

describe 'Packages' do
  include Rack::Test::Methods
  include ControllerHelpers

  def app
    test_config     = TestConfig.config
    request_metrics = VCAP::CloudController::Metrics::RequestMetrics.new
    VCAP::CloudController::RackAppBuilder.new.build test_config, request_metrics
  end

  let(:user) { VCAP::CloudController::User.make }
  let(:user_header) { headers_for(user)['HTTP_AUTHORIZATION'] }
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
    let(:data) do # 'docker://cloudfoundry/runtime-ci'
      {
        image: 'registry/image:latest'
      }
    end

    describe 'creation' do
      it "creates a package" do
        expect {
          post "/v3/apps/#{guid}/packages", { type: type, data: data }, headers_for(user)
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

        parsed_response = MultiJson.load(last_response.body)
        expect(last_response.status).to eq(201)
        expect(parsed_response).to be_a_response_like(expected_response)
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

      it "copies a package" do
        expect {
          post "/v3/apps/#{guid}/packages?source_package_guid=#{source_package_guid}", {}, headers_for(user)
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
      end

    end

    describe 'GET /v3/apps/:guid/packages' do
      let(:space) { VCAP::CloudController::Space.make }
      let!(:package) { VCAP::CloudController::PackageModel.make(app_guid: app_model.guid) }

      let(:app_model) { VCAP::CloudController::AppModel.make(space_guid: space.guid) }
      let(:guid) { app_model.guid }

      before do
        space.organization.add_user(user)
        space.add_developer(user)
      end

      it 'List associated packages' do
        expected_response = {
          'pagination' => {
            'total_results' => 1,
            'first'         => { 'href' => "/v3/apps/#{guid}/packages?page=1&per_page=50" },
            'last'          => { 'href' => "/v3/apps/#{guid}/packages?page=1&per_page=50" },
            'next'          => nil,
            'previous'      => nil,
          },
          'resources' => [
            {
              'guid'       => package.guid,
              'type'       => 'bits',
              'data'       => {
                'hash'       => { 'type' => 'sha1', 'value' => nil },
                'error'      => nil
              },
              'url'        => nil,
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
            }
          ]
        }

        get "/v3/apps/#{guid}/packages", {}, headers_for(user)

        parsed_response = MultiJson.load(last_response.body)

        expect(last_response.status).to eq(200)
        expect(parsed_response).to be_a_response_like(expected_response)
      end
    end

    describe 'GET /v3/packages' do
      let(:type1) { 'bits' }
      let(:type2) { 'docker' }
      let(:type3) { 'docker' }
      let!(:package1) { VCAP::CloudController::PackageModel.make(type: type1, app_guid: app_model.guid) }
      let!(:package2) do
        VCAP::CloudController::PackageModel.make(type: type2, app_guid: app_model.guid,
                                                 state: VCAP::CloudController::PackageModel::READY_STATE,
                                                )
      end
      let!(:package3) { VCAP::CloudController::PackageModel.make(type: type3, app_guid: app_model.guid) }
      let!(:package4) { VCAP::CloudController::PackageModel.make(app_guid: VCAP::CloudController::AppModel.make.guid) }
      let(:page) { 1 }
      let(:per_page) { 2 }

      before do
        space.organization.add_user(user)
        space.add_developer(user)

        VCAP::CloudController::PackageDockerDataModel.create(package: package2, image: 'http://location-of-image.com')
        VCAP::CloudController::PackageDockerDataModel.create(package: package3, image: 'http://location-of-image-2.com')
      end

      it 'gets all the packages' do
        expected_response =
          {
            'pagination' => {
              'total_results' => 3,
              'first'         => { 'href' => '/v3/packages?page=1&per_page=2' },
              'last'          => { 'href' => '/v3/packages?page=2&per_page=2' },
              'next'          => { 'href' => '/v3/packages?page=2&per_page=2' },
              'previous'      => nil,
            },
            'resources' => [
              {
                'guid'       => package1.guid,
                'type'       => 'bits',
                'data'       => {
                  'hash'       => { 'type' => 'sha1', 'value' => nil },
                  'error'      => nil
                },
                'state'      => VCAP::CloudController::PackageModel::CREATED_STATE,
                'created_at' => iso8601,
                'updated_at' => nil,
                'links' => {
                  'self'   => { 'href' => "/v3/packages/#{package1.guid}" },
                  'upload' => { 'href' => "/v3/packages/#{package1.guid}/upload", 'method' => 'POST' },
                  'download' => { 'href' => "/v3/packages/#{package1.guid}/download", 'method' => 'GET' },
                  'stage' => { 'href' => "/v3/packages/#{package1.guid}/droplets", 'method' => 'POST' },
                  'app' => { 'href' => "/v3/apps/#{package1.app_guid}" },
                }
              },
              {
                'guid'       => package2.guid,
                'type'       => 'docker',
                'data'       => {
                  'image'    => 'http://location-of-image.com'
                },
                'state'      => VCAP::CloudController::PackageModel::READY_STATE,
                'created_at' => iso8601,
                'updated_at' => nil,
                'links' => {
                  'self' => { 'href' => "/v3/packages/#{package2.guid}" },
                  'app'  => { 'href' => "/v3/apps/#{package2.app_guid}" },
                  'stage' => { 'href' => "/v3/packages/#{package2.guid}/droplets", 'method' => 'POST' },
                }
              }
            ]
        }

          get '/v3/packages', { per_page: per_page }, headers_for(user)

          parsed_response = MultiJson.load(last_response.body)
          expect(last_response.status).to eq(200)
          expect(parsed_response).to be_a_response_like(expected_response)
      end
    end

  end
end
