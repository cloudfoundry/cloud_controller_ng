require 'spec_helper'

RSpec.describe 'Builds' do
  let(:email) { 'potato@house.com' }
  let(:user) { VCAP::CloudController::User.make }
  let(:user_name) { 'clarence' }
  let(:user_header) { headers_for(user, email: email, user_name: user_name) }
  let(:space) { VCAP::CloudController::Space.make }
  let(:space_guid) { space.guid }
  let(:app_model) { VCAP::CloudController::AppModel.make(space_guid: space_guid) }
  let(:package) do
    VCAP::CloudController::PackageModel.make(
      app_guid: app_model.guid,
      state: VCAP::CloudController::PackageModel::READY_STATE,
      type: VCAP::CloudController::PackageModel::BITS_TYPE,
    )
  end

  describe 'POST /v3/builds' do
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
    let(:payload) do
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
      allow_any_instance_of(CloudController::Blobstore::UrlGenerator).to receive(:v3_app_buildpack_cache_download_url).and_return('some-string')
      allow_any_instance_of(CloudController::Blobstore::UrlGenerator).to receive(:v3_app_buildpack_cache_upload_url).and_return('some-string')
      allow_any_instance_of(CloudController::Blobstore::UrlGenerator).to receive(:package_download_url).and_return('some-string')
      allow_any_instance_of(CloudController::Blobstore::UrlGenerator).to receive(:package_droplet_upload_url).and_return('some-string')
      stub_request(:put, %r{#{TestConfig.config[:diego][:stager_url]}/v1/staging/}).
        to_return(status: 202, body: diego_staging_response.to_json)
    end

    it 'creates a Builds resource' do
      expect {
        post '/v3/builds', payload, user_header
      }.to change { VCAP::CloudController::BuildModel.count }.by(1)

      expect(last_response.status).to eq(201), "Expected status code 201. Got #{last_response.status}. Response body: #{last_response.body}"
      build = VCAP::CloudController::BuildModel.last

      expect(decoded_response).to be_a_response_like({
        'guid' => build.guid,
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
        'droplet' => {
          'guid' => build.droplet.guid
        },
        'links' => {
          'self' => {
            'href' => "#{link_prefix}/v3/builds/#{build.guid}"
          },
          'app' => {
            'href' => "#{link_prefix}/v3/apps/#{app_model.guid}"
          }
        }
      })
    end
  end
end
