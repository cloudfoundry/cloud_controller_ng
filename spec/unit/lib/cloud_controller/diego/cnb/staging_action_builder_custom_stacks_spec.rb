require 'spec_helper'
require 'cloud_controller/diego/cnb/staging_action_builder'

module VCAP::CloudController
  module Diego
    module CNB
      RSpec.describe StagingActionBuilder do
        let(:stack_name) { 'cflinuxfs4' }
        let(:lifecycle_data) do
          {
            app_bits_download_uri: 'http://app.example.com/bits.zip',
            build_artifacts_cache_upload_uri: 'http://cache.example.com/upload',
            droplet_upload_uri: 'http://droplet.example.com/upload',
            buildpacks: [],
            stack: stack_name,
            app_bits_checksum: { type: 'sha256', value: 'checksum' },
            auto_detect: true
          }
        end
        let(:config) do
          Config.new({
            diego: {
              lifecycle_bundles: { 'cnb/default-stack-name': 'http://lifecycle.example.com/cnb-bundle.tgz' },
              droplet_destinations: { 'default-stack-name': '/home/vcap' },
              enable_declarative_asset_downloads: false,
              cc_uploader_url: 'http://uploader.example.com'
            },
            staging: {
              timeout_in_seconds: 900,
              legacy_md5_buildpack_paths_enabled: false
            }
          })
        end
        let(:staging_details) { instance_double(StagingDetails, staging_guid: 'staging-guid') }

        subject(:builder) { StagingActionBuilder.new(config, staging_details, lifecycle_data) }

        before do
          VCAP::CloudController::Stack.find(name: 'cflinuxfs4') || VCAP::CloudController::Stack.create(name: 'cflinuxfs4')
        end

        describe '#task_environment_variables' do
          context 'with a system stack' do
            it 'includes CNB_STACK_ID set to the stack name' do
              env_vars = builder.task_environment_variables
              stack_id_var = env_vars.find { |v| v.name == 'CNB_STACK_ID' }
              expect(stack_id_var).not_to be_nil
              expect(stack_id_var.value).to eq('cflinuxfs4')
            end
          end

          context 'with a custom stack and no explicit stack_id' do
            let(:stack_name) { 'docker://docker.io/cloudfoundry/cflinuxfs4:1.268.0' }

            it 'omits CNB_STACK_ID (auto-detect)' do
              env_vars = builder.task_environment_variables
              stack_id_var = env_vars.find { |v| v.name == 'CNB_STACK_ID' }
              expect(stack_id_var).to be_nil
            end
          end

          context 'with a custom stack and an explicit stack_id' do
            let(:stack_name) { 'docker://docker.io/cloudfoundry/cflinuxfs4:1.268.0' }
            let(:lifecycle_data) do
              {
                app_bits_download_uri: 'http://app.example.com/bits.zip',
                build_artifacts_cache_upload_uri: 'http://cache.example.com/upload',
                droplet_upload_uri: 'http://droplet.example.com/upload',
                buildpacks: [],
                stack: stack_name,
                stack_id: 'io.buildpacks.stacks.jammy',
                app_bits_checksum: { type: 'sha256', value: 'checksum' },
                auto_detect: true
              }
            end

            it 'uses the provided stack_id' do
              env_vars = builder.task_environment_variables
              stack_id_var = env_vars.find { |v| v.name == 'CNB_STACK_ID' }
              expect(stack_id_var).not_to be_nil
              expect(stack_id_var.value).to eq('io.buildpacks.stacks.jammy')
            end
          end

          context 'with credentials in lifecycle_data' do
            let(:lifecycle_data) do
              {
                app_bits_download_uri: 'http://app.example.com/bits.zip',
                build_artifacts_cache_upload_uri: 'http://cache.example.com/upload',
                droplet_upload_uri: 'http://droplet.example.com/upload',
                buildpacks: [],
                stack: stack_name,
                app_bits_checksum: { type: 'sha256', value: 'checksum' },
                auto_detect: true,
                credentials: '{"docker.io":{"username":"user","password":"pass"}}'
              }
            end

            it 'includes CNB_REGISTRY_CREDS' do
              env_vars = builder.task_environment_variables
              creds_var = env_vars.find { |v| v.name == 'CNB_REGISTRY_CREDS' }
              expect(creds_var).not_to be_nil
              expect(creds_var.value).to include('docker.io')
            end
          end
        end

        describe '#stack' do
          context 'with a custom stack' do
            let(:stack_name) { 'docker://docker.io/cloudfoundry/cflinuxfs4:1.268.0' }

            it 'returns docker:// rootfs in Diego format' do
              expect(builder.stack).to eq('docker://docker.io/cloudfoundry/cflinuxfs4#1.268.0')
            end
          end
        end
      end
    end
  end
end
