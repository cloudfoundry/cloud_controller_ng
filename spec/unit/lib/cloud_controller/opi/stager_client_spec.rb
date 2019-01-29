require 'spec_helper'
require 'cloud_controller/opi/stager_client'

RSpec.describe(OPI::StagerClient) do
  let(:config) { TestConfig.config_instance }
  let(:eirini_url) { 'http://eirini.loves.heimdall:777' }

  let(:staging_details) { stub_staging_details }
  let(:lifecycle_data) { stub_lifecycle_data }

  let(:lifecycle_environment_variables) { [
    ::Diego::Bbs::Models::EnvironmentVariable.new(name: 'VCAP_APPLICATION', value: '{"wow":"pants"}'),
    ::Diego::Bbs::Models::EnvironmentVariable.new(name: 'MEMORY_LIMIT', value: '256m'),
    ::Diego::Bbs::Models::EnvironmentVariable.new(name: 'VCAP_SERVICES', value: '{}')
  ]
  }

  let(:staging_action_builder) do
    instance_double(VCAP::CloudController::Diego::Buildpack::StagingActionBuilder,
      task_environment_variables: lifecycle_environment_variables,
      lifecycle_data: lifecycle_data,
    )
  end

  let(:lifecycle_protocol) do
    instance_double(VCAP::CloudController::Diego::Buildpack::LifecycleProtocol,
      staging_action_builder: staging_action_builder
    )
  end

  subject(:stager_client) { described_class.new(eirini_url, config) }

  context 'when staging an app' do
    before do
      allow(VCAP::CloudController::Diego::Buildpack::LifecycleProtocol).to receive(:new).and_return(lifecycle_protocol)

      stub_request(:post, "#{eirini_url}/stage/guid").
        to_return(status: 202)
    end

    it 'should send the expected request' do
      stager_client.stage('guid', staging_details)
      expect(WebMock).to have_requested(:post, "#{eirini_url}/stage/guid").with(body: {
        app_guid: 'thor',
        environment: [{ name: 'VCAP_APPLICATION', value: '{"wow":"pants"}' },
                      { name: 'MEMORY_LIMIT', value: '256m' },
                      { name: 'VCAP_SERVICES', value: '{}' }],
         completion_callback: 'https://internal_user:internal_password@api.internal.cf:8182/internal/v3/staging//build_completed?start=',
        lifecycle_data: { droplet_upload_uri: 'http://cc-uploader.service.cf.internal:9091/v1/droplet/guid?cc-droplet-upload-uri=http://upload.me',
                          app_bits_download_uri: 'http://download.me',
                          buildpacks: [{ name: 'ruby', key: 'idk', url: 'www.com', skip_detect: false }]
      } }.to_json
      )
    end

    context 'when the response contains an error' do
      before do
        stub_request(:post, "#{eirini_url}/stage/guid").
          to_return(status: 501, body: { 'error' => 'argh' }.to_json)
      end

      it 'should raise an error' do
        expect { stager_client.stage('guid', staging_details) }.to raise_error(CloudController::Errors::ApiError)
      end
    end
  end

  def stub_staging_details
    staging_details                                 = VCAP::CloudController::Diego::StagingDetails.new
    staging_details.package                         = double(app_guid: 'thor')
    staging_details.lifecycle                       = double(type: VCAP::CloudController::Lifecycles::BUILDPACK)
    staging_details
  end

  def stub_lifecycle_data
    data                                            = VCAP::CloudController::Diego::Buildpack::LifecycleData.new
    data.app_bits_download_uri                      = 'http://download.me'
    data.buildpacks                                 = [
      {
           name: 'ruby',
           key: 'idk',
           url: 'www.com',
           skip_detect: false
       }
    ]
    data.droplet_upload_uri                         = 'http://upload.me'
    data.build_artifacts_cache_download_uri         = 'dont care'
    data.stack                                      = 'dont care'
    data.build_artifacts_cache_upload_uri           = 'dont care'
    data.buildpack_cache_checksum                   = 'dont care'
    data.app_bits_checksum                          = { type: 'sha256', value: 'also dont care' }
    data.message
  end
end
