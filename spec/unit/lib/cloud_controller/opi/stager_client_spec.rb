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
      internal_service_hostname: 'api.internal.cf',
      internal_service_port:     '9090',
      kubernetes: kubernetes_config,
    )
  end
  let(:eirini_url) { 'http://eirini.loves.heimdall:777' }
  let(:staging_guid) { 'some_staging_guid' }
  let(:kubernetes_config) { {} }

  let(:staging_details) { stub_staging_details(lifecycle_type, staging_guid) }
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
      stub_request(:post, "#{eirini_url}/stage/#{staging_guid}").
        to_return(status: 202)
    end

    context 'when lifecycle type is buildpack' do
      let(:lifecycle_type) { VCAP::CloudController::Lifecycles::BUILDPACK }

      before do
        allow(VCAP::CloudController::Diego::Buildpack::LifecycleProtocol).to receive(:new).and_return(lifecycle_protocol)
      end

      it 'should send the expected request' do
        stager_client.stage(staging_guid, staging_details)
        expect(WebMock).to have_requested(:post, "#{eirini_url}/stage/#{staging_guid}").with(body: {
          app_guid: 'thor',
          app_name: 'the_thor',
          staging_guid: staging_guid,
          org_name: 'some-org',
          org_guid: 'some-org-guid',
          space_name: 'outer',
          space_guid: 'outer-guid',
          environment: [{ name: 'VCAP_APPLICATION', value: '{"wow":"pants"}' },
                        { name: 'MEMORY_LIMIT', value: '256m' },
                        { name: 'VCAP_SERVICES', value: '{}' }],
          completion_callback: 'https://internal_user:internal_password@api.internal.cf:8182/internal/v3/staging/some_staging_guid/build_completed?start=',
          lifecycle: {
            buildpack_lifecycle: {
              droplet_upload_uri: "http://cc-uploader.service.cf.internal:9091/v1/droplet/#{staging_guid}?cc-droplet-upload-uri=http://upload.me",
                              app_bits_download_uri: 'http://download.me',
                              buildpacks: [{ name: 'ruby', key: 'idk', url: 'www.com', skip_detect: false }],
                              buildpack_cache_download_uri: 'buildpacks-artifacts-cache-url-download',
                              buildpack_cache_checksum: 'sumcheck',
                              buildpack_cache_checksum_algorithm: 'sha256',
                              buildpack_cache_upload_uri: 'https://cc-uploader.service.cf.internal:9091/v1/build_artifacts/some_staging_guid?cc-build-artifacts-upload-uri=buildpacks-artifacts-cache-url-upload&timeout=42'
            }
          },
          cpu_weight: VCAP::CloudController::Diego::STAGING_TASK_CPU_WEIGHT,
          disk_mb: 100,
          memory_mb: 200
        }.to_json
        )
      end

      context 'when staging details includes env vars' do
        before do
          staging_details.environment_variables = { GOPACKAGE: 'github.com/some/go/pkg' }
        end

        it 'should include the staging details env vars in the request' do
          stager_client.stage(staging_guid, staging_details)
          expect(WebMock).to have_requested(:post, "#{eirini_url}/stage/#{staging_guid}").with(body: {
            app_guid: 'thor',
            app_name: 'the_thor',
            staging_guid: staging_guid,
            org_name: 'some-org',
            org_guid: 'some-org-guid',
            space_name: 'outer',
            space_guid: 'outer-guid',
            environment: [{ name: 'GOPACKAGE', value: 'github.com/some/go/pkg' },
                          { name: 'VCAP_APPLICATION', value: '{"wow":"pants"}' },
                          { name: 'MEMORY_LIMIT', value: '256m' },
                          { name: 'VCAP_SERVICES', value: '{}' }],
            completion_callback: 'https://internal_user:internal_password@api.internal.cf:8182/internal/v3/staging/some_staging_guid/build_completed?start=',
            lifecycle: {
              buildpack_lifecycle: {
                droplet_upload_uri: "http://cc-uploader.service.cf.internal:9091/v1/droplet/#{staging_guid}?cc-droplet-upload-uri=http://upload.me",
                                app_bits_download_uri: 'http://download.me',
                                buildpacks: [{ name: 'ruby', key: 'idk', url: 'www.com', skip_detect: false }],
                                buildpack_cache_download_uri: 'buildpacks-artifacts-cache-url-download',
                                buildpack_cache_checksum: 'sumcheck',
                                buildpack_cache_checksum_algorithm: 'sha256',
                                buildpack_cache_upload_uri: 'https://cc-uploader.service.cf.internal:9091/v1/build_artifacts/some_staging_guid?cc-build-artifacts-upload-uri=buildpacks-artifacts-cache-url-upload&timeout=42'
              }
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
          stub_request(:post, "#{eirini_url}/stage/#{staging_guid}").
            to_return(status: 501, body: { 'message' => 'failed to stage' }.to_json)
        end

        it 'should raise an error' do
          expect { stager_client.stage(staging_guid, staging_details) }.to raise_error(CloudController::Errors::ApiError, 'Runner error: failed to stage')
        end
      end
    end

    context 'when lifecycle type is docker' do
      let(:lifecycle_type) { VCAP::CloudController::Lifecycles::DOCKER }

      let(:staging_action_builder) do
        instance_double(VCAP::CloudController::Diego::Docker::StagingActionBuilder,
          task_environment_variables: lifecycle_environment_variables,
        )
      end

      let(:lifecycle_protocol) do
        instance_double(VCAP::CloudController::Diego::Docker::LifecycleProtocol,
          staging_action_builder: staging_action_builder
        )
      end

      before do
        allow(VCAP::CloudController::Diego::Docker::LifecycleProtocol).to receive(:new).and_return(lifecycle_protocol)
      end

      it 'should set a docker lifecycle' do
        stager_client.stage(staging_guid, staging_details)
        expect(WebMock).to have_requested(:post, "#{eirini_url}/stage/#{staging_guid}").with(body: {
          app_guid: 'thor',
          app_name: 'the_thor',
          staging_guid: staging_guid,
          org_name: 'some-org',
          org_guid: 'some-org-guid',
          space_name: 'outer',
          space_guid: 'outer-guid',
          environment: [{ name: 'VCAP_APPLICATION', value: '{"wow":"pants"}' },
                        { name: 'MEMORY_LIMIT', value: '256m' },
                        { name: 'VCAP_SERVICES', value: '{}' }],
          completion_callback: 'https://internal_user:internal_password@api.internal.cf:8182/internal/v3/staging/some_staging_guid/build_completed?start=',
          lifecycle: {
            docker_lifecycle: {
              image: 'docker.io/some/image',
              registry_username: 'theone',
              registry_password: 'notone'
            }
          },
          cpu_weight: VCAP::CloudController::Diego::STAGING_TASK_CPU_WEIGHT,
          disk_mb: 100,
          memory_mb: 200
        }.to_json
        )
      end

      context 'when kubernetes is configured' do
        let(:kubernetes_config) do
          {
            host_url: 'https://main.default.svc.cluster-domain.example',
          }
        end

        it 'configures the callback url with http and relies on Istio for mTLS' do
          stager_client.stage(staging_guid, staging_details)
          expect(WebMock).to have_requested(:post, "#{eirini_url}/stage/#{staging_guid}").with { |req|
            parsed_json = JSON.parse(req.body)
            parsed_json['completion_callback'] == 'http://api.internal.cf:9090/internal/v3/staging/some_staging_guid/build_completed?start='
          }
        end
      end
    end
  end

  context 'when lifecycle type is invalid' do
    let(:lifecycle_type) { 'dockerpack' }

    it 'should raise an error' do
      expect {
        stager_client.stage(staging_guid, staging_details)
      }.to raise_error(RuntimeError, 'lifecycle type `dockerpack` is invalid')
    end
  end

  def stub_staging_details(lifecycle_type, staging_guid)
    space = VCAP::CloudController::Space.make(
      name: 'outer',
      guid: 'outer-guid',
      organization: VCAP::CloudController::Organization.make(name: 'some-org', guid: 'some-org-guid'))

    app_model = VCAP::CloudController::AppModel.make(
      guid: 'thor',
      name: 'the_thor',
      space: space)

    package_model = VCAP::CloudController::PackageModel.make(
      type: 'docker',
      docker_image: 'docker.io/some/image',
      docker_username: 'theone',
      docker_password: 'notone',
      app: app_model)

    staging_details                                 = VCAP::CloudController::Diego::StagingDetails.new
    staging_details.package                         = package_model
    staging_details.lifecycle                       = double(type: lifecycle_type)
    staging_details.staging_disk_in_mb              = 100
    staging_details.staging_memory_in_mb            = 200
    staging_details.staging_guid                    = staging_guid
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
    data.build_artifacts_cache_download_uri         = 'buildpacks-artifacts-cache-url-download'
    data.stack                                      = 'dont care'
    data.build_artifacts_cache_upload_uri           = 'buildpacks-artifacts-cache-url-upload'
    data.buildpack_cache_checksum                   = 'sumcheck'
    data.app_bits_checksum                          = { type: 'sha256', value: 'also dont care' }
    data.message
  end
end
