require 'spec_helper'
require 'cloud_controller/opi/stager_client'

RSpec.describe(OPI::StagerClient) do
  let(:config) do
    TestConfig.override(
      opi: {
        url: eirini_url,
        cc_uploader_url: 'http://cc-uploader.service.cf.internal:9091'
      },
      tls_port: 8182,
      internal_api: {
        auth_user: 'internal_user',
        auth_password: 'internal_password'
      },
      internal_service_hostname: 'api.internal.cf'
    )
  end
  let(:eirini_url) { 'http://eirini.loves.heimdall:777' }

  let(:staging_details) { stub_staging_details(lifecycle_type) }
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

  subject(:stager_client) { described_class.new(config) }

  context 'when staging an app' do
    before do
      allow(VCAP::CloudController::Diego::Buildpack::LifecycleProtocol).to receive(:new).and_return(lifecycle_protocol)

      stub_request(:post, "#{eirini_url}/stage/guid").
        to_return(status: 202)
    end

    context 'when lifecycle type is buildpack' do
      let(:lifecycle_type) { VCAP::CloudController::Lifecycles::BUILDPACK }
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
          },
          cpu_weight: VCAP::CloudController::Diego::STAGING_TASK_CPU_WEIGHT,
          disk_mb: 100,
          memory_mb: 200
        }.to_json
        )
      end

      context 'when staging details includes env vars' do
        before do
          staging_details.environment_variables = { 'GOPACKAGE': 'github.com/some/go/pkg' }
        end

        it 'should include the staging details env vars in the request' do
          stager_client.stage('guid', staging_details)
          expect(WebMock).to have_requested(:post, "#{eirini_url}/stage/guid").with(body: {
            app_guid: 'thor',
            environment: [{ name: 'GOPACKAGE', value: 'github.com/some/go/pkg' },
                          { name: 'VCAP_APPLICATION', value: '{"wow":"pants"}' },
                          { name: 'MEMORY_LIMIT', value: '256m' },
                          { name: 'VCAP_SERVICES', value: '{}' }],
            completion_callback: 'https://internal_user:internal_password@api.internal.cf:8182/internal/v3/staging//build_completed?start=',
            lifecycle_data: { droplet_upload_uri: 'http://cc-uploader.service.cf.internal:9091/v1/droplet/guid?cc-droplet-upload-uri=http://upload.me',
                              app_bits_download_uri: 'http://download.me',
                              buildpacks: [{ name: 'ruby', key: 'idk', url: 'www.com', skip_detect: false }]
            },
            cpu_weight: VCAP::CloudController::Diego::STAGING_TASK_CPU_WEIGHT,
            disk_mb: 100,
            memory_mb: 200
          }.to_json
          )
        end
      end

      context 'when the response contains an error' do
        before do
          stub_request(:post, "#{eirini_url}/stage/guid").
            to_return(status: 501, body: { 'message' => 'failed to stage' }.to_json)
        end

        it 'should raise an error' do
          expect { stager_client.stage('guid', staging_details) }.to raise_error(CloudController::Errors::ApiError, 'Runner error: failed to stage')
        end
      end
    end

    context 'when lifecycle type is docker' do
      let(:lifecycle_type) { VCAP::CloudController::Lifecycles::DOCKER }
      let(:staging_completion_handler) { instance_double(VCAP::CloudController::Diego::Docker::StagingCompletionHandler) }
      let(:build_model) { instance_double(VCAP::CloudController::BuildModel) }
      let(:payload) {
        {
        result: {
          lifecycle_type: 'docker',
          lifecycle_metadata: {
            docker_image: 'docker.io/some/image'
          },
          process_types: { web: '' },
          execution_metadata: '{\"cmd\":[],\"ports\":[{\"Port\":8080,\"Protocol\":\"tcp\"}]}'
        }
      }
      }

      it 'should not make any http calls to eirini' do
        allow(VCAP::CloudController::BuildModel).to receive(:find).and_return(build_model)
        allow(VCAP::CloudController::Diego::Docker::StagingCompletionHandler).to receive(:new).and_return(staging_completion_handler)
        allow(staging_completion_handler).to receive(:staging_complete)

        stager_client.stage('some_staging_guid', staging_details)
        expect(WebMock).not_to have_requested(:any, "#{eirini_url}/stage/some_staging_guid")
      end

      it 'should mark staging as completed' do
        expect(VCAP::CloudController::BuildModel).to receive(:find).with(guid: 'some_staging_guid').and_return(build_model)
        expect(VCAP::CloudController::Diego::Docker::StagingCompletionHandler).to receive(:new).with(build_model).and_return(staging_completion_handler)
        expect(staging_completion_handler).to receive(:staging_complete).with(payload, true)

        staging_details.start_after_staging = true
        stager_client.stage('some_staging_guid', staging_details)
      end

      context 'when build is not found' do
        it 'should raise an error' do
          expect(VCAP::CloudController::BuildModel).to receive(:find).with(guid: 'some_staging_guid').and_return(nil)
          expect {
            stager_client.stage('some_staging_guid', staging_details)
          }.to raise_error(CloudController::Errors::ApiError, 'Build not found')
        end
      end
    end

    context 'when lifecycle type is invalid' do
      let(:lifecycle_type) { 'dockerpack' }

      it 'should raise an error' do
        expect {
          stager_client.stage('some_staging_guid', staging_details)
        }.to raise_error(RuntimeError, 'lifecycle type `dockerpack` is invalid')
      end
    end
  end

  def stub_staging_details(lifecycle_type)
    staging_details                                 = VCAP::CloudController::Diego::StagingDetails.new
    staging_details.package                         = double(app_guid: 'thor', image: 'docker.io/some/image')
    staging_details.lifecycle                       = double(type: lifecycle_type)
    staging_details.staging_disk_in_mb              = 100
    staging_details.staging_memory_in_mb            = 200
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
