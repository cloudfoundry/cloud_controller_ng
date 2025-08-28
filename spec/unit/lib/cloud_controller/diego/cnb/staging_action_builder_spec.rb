require 'spec_helper'
require 'cloud_controller/diego/cnb/staging_action_builder'

module VCAP::CloudController
  module Diego
    module CNB
      RSpec.describe StagingActionBuilder do
        subject(:builder) { StagingActionBuilder.new(config, staging_details, lifecycle_data) }

        let(:droplet) { DropletModel.make(:buildpack) }
        let(:enable_declarative_asset_downloads) { false }
        let(:legacy_md5_buildpack_paths_enabled) { false }
        let(:config) do
          Config.new({
                       skip_cert_verify: false,
                       diego: {
                         cc_uploader_url: 'http://cc-uploader.example.com',
                         file_server_url: 'http://file-server.example.com',
                         lifecycle_bundles: {
                           'cnb/buildpack-stack': 'the-buildpack-bundle'
                         },
                         enable_declarative_asset_downloads: enable_declarative_asset_downloads
                       },
                       staging: {
                         legacy_md5_buildpack_paths_enabled: legacy_md5_buildpack_paths_enabled,
                         minimum_staging_file_descriptor_limit: 4,
                         timeout_in_seconds: 90
                       }
                     })
        end
        let(:staging_details) do
          StagingDetails.new.tap do |details|
            details.staging_guid          = droplet.guid
            details.environment_variables = env
          end
        end
        let(:env) do
          {
            FOO: 'bar',
            BAR: 'baz'
          }
        end
        let(:bbs_env) do
          [
            ::Diego::Bbs::Models::EnvironmentVariable.new(name: 'FOO', value: 'bar'),
            ::Diego::Bbs::Models::EnvironmentVariable.new(name: 'BAR', value: 'baz')
          ]
        end
        let(:stack) { 'buildpack-stack' }
        let(:lifecycle_data) do
          {
            app_bits_download_uri: 'http://app_bits_download_uri.example.com/path/to/bits',
            build_artifacts_cache_download_uri: 'http://build_artifacts_cache_download_uri.example.com/path/to/bits',
            build_artifacts_cache_upload_uri: 'http://build_artifacts_cache_upload_uri.example.com/path/to/bits',
            buildpacks: buildpacks,
            droplet_upload_uri: 'http://droplet_upload_uri.example.com/path/to/bits',
            stack: stack,
            buildpack_cache_checksum: 'bp-cache-checksum',
            app_bits_checksum: { type: 'sha256', value: 'package-checksum' }
          }
        end
        let(:buildpacks) { [] }
        let(:generated_environment) do
          [
            ::Diego::Bbs::Models::EnvironmentVariable.new(name: 'CNB_USER_ID', value: '2000'),
            ::Diego::Bbs::Models::EnvironmentVariable.new(name: 'CNB_GROUP_ID', value: '2000'),
            ::Diego::Bbs::Models::EnvironmentVariable.new(name: 'CNB_REGISTRY_CREDS', value: '{"auth": {}}')
          ]
        end

        before do
          allow(LifecycleBundleUriGenerator).to receive(:uri).with('the-buildpack-bundle').and_return('generated-uri')
          allow(BbsEnvironmentBuilder).to receive(:build).with(env).and_return(bbs_env)
          TestConfig.override(credhub_api: nil)

          Stack.create(name: 'buildpack-stack')
        end

        describe '#action' do
          let(:download_app_package_action) do
            ::Diego::Bbs::Models::DownloadAction.new(
              artifact: 'app package',
              from: 'http://app_bits_download_uri.example.com/path/to/bits',
              to: '/home/vcap/workspace',
              user: 'vcap',
              checksum_algorithm: 'sha256',
              checksum_value: 'package-checksum'
            )
          end

          let(:download_build_artifacts_cache_action) do
            ::Diego::Bbs::Models::DownloadAction.new(
              artifact: 'build artifacts cache',
              from: 'http://build_artifacts_cache_download_uri.example.com/path/to/bits',
              to: '/tmp/cache',
              user: 'vcap',
              checksum_algorithm: 'sha256',
              checksum_value: 'bp-cache-checksum'
            )
          end

          let(:droplet_upload_url) { CGI.escape('http://droplet_upload_uri.example.com/path/to/bits') }
          let(:upload_droplet_action) do
            ::Diego::Bbs::Models::UploadAction.new(
              artifact: 'droplet',
              from: '/tmp/droplet',
              to: "http://cc-uploader.example.com/v1/droplet/#{droplet.guid}?cc-droplet-upload-uri=#{droplet_upload_url}&timeout=90",
              user: 'vcap'
            )
          end

          let(:cache_upload_url) { CGI.escape('http://build_artifacts_cache_upload_uri.example.com/path/to/bits') }
          let(:upload_build_artifacts_cache_action) do
            ::Diego::Bbs::Models::UploadAction.new(
              artifact: 'build artifacts cache',
              from: '/tmp/cache-output.tgz',
              to: "http://cc-uploader.example.com/v1/build_artifacts/#{droplet.guid}?cc-build-artifacts-upload-uri=#{cache_upload_url}&timeout=90",
              user: 'vcap'
            )
          end

          let(:run_staging_action) do
            ::Diego::Bbs::Models::RunAction.new(
              path: '/tmp/lifecycle/builder',
              user: 'vcap',
              args: ['--cache-dir', '/tmp/cache', '--cache-output', '/tmp/cache-output.tgz', '--buildpack', 'docker.io/paketobuildpacks/node-start', '--buildpack',
                     'docker.io/paketobuildpacks/node-engine', '--pass-env-var', 'FOO', '--pass-env-var', 'BAR'],
              env: bbs_env
            )
          end

          let(:buildpacks) do
            [
              { name: 'custom', url: 'docker.io/paketobuildpacks/node-start', skip_detect: false },
              { name: 'custom', url: 'docker.io/paketobuildpacks/node-engine', skip_detect: false }
            ]
          end

          it 'returns the correct buildpack staging action structure' do
            result = builder.action

            serial_action = result.serial_action
            actions       = serial_action.actions

            parallel_download_action = actions[0].parallel_action
            expect(parallel_download_action.actions[0].download_action).to eq(download_app_package_action)
            expect(parallel_download_action.actions[1].try_action.action.download_action).to eq(download_build_artifacts_cache_action)

            expect(actions[1].run_action).to eq(run_staging_action)

            emit_progress_action = actions[2].emit_progress_action
            expect(emit_progress_action.start_message).to eq('Uploading droplet, build artifacts cache...')
            expect(emit_progress_action.success_message).to eq('Uploading complete')
            expect(emit_progress_action.failure_message_prefix).to eq('Uploading failed')

            parallel_upload_action = actions[2].emit_progress_action.action
            expect(parallel_upload_action.parallel_action).not_to be_nil
            upload_actions = parallel_upload_action.parallel_action.actions
            expect(upload_actions[0].upload_action).to eq(upload_droplet_action)
            expect(upload_actions[1].upload_action).to eq(upload_build_artifacts_cache_action)
          end

          describe 'credhub' do
            let(:credhub_url) { TestConfig.config_instance.get(:credhub_api, :internal_url) }
            let(:expected_platform_options) do
              [
                ::Diego::Bbs::Models::EnvironmentVariable.new(
                  name: 'VCAP_PLATFORM_OPTIONS',
                  value: '{"credhub-uri":"https://credhub.capi.internal:8844"}'
                )
              ]
            end
            let(:expected_credhub_arg) do
              { 'VCAP_PLATFORM_OPTIONS' => { 'credhub-uri' => credhub_url } }
            end

            context 'when credhub url is present' do
              context 'when the interpolation of service bindings is enabled' do
                before do
                  TestConfig.override(credential_references: { interpolate_service_bindings: true })
                end

                it 'sends the credhub_url in the environment variables' do
                  result = builder.action
                  actions = result.serial_action.actions

                  expect(actions[1].run_action.env).to eq(bbs_env + expected_platform_options)
                end
              end

              context 'when the interpolation of service bindings is disabled' do
                before do
                  TestConfig.override(credential_references: { interpolate_service_bindings: false })
                end

                it 'does not send the credhub_url in the environment variables' do
                  result = builder.action
                  actions = result.serial_action.actions

                  expect(actions[1].run_action.env).to eq(bbs_env)
                end
              end
            end
          end

          context 'when there is no buildpack cache' do
            before do
              lifecycle_data[:build_artifacts_cache_download_uri] = nil
            end

            it 'does not include the builpack cache download action' do
              result = builder.action

              serial_action = result.serial_action
              actions       = serial_action.actions

              parallel_download_action = actions[0].parallel_action
              expect(parallel_download_action.actions.count).to eq(1)
              expect(parallel_download_action.actions.first.download_action).not_to eq(download_build_artifacts_cache_action)
            end
          end

          context 'when there is no buildpack cache checksum' do
            before do
              lifecycle_data[:buildpack_cache_checksum] = ''
            end

            it 'does not include the builpack cache download action' do
              result = builder.action

              serial_action = result.serial_action
              actions       = serial_action.actions

              parallel_download_action = actions[0].parallel_action
              expect(parallel_download_action.actions.count).to eq(1)
              expect(parallel_download_action.actions.first.download_action).not_to eq(download_build_artifacts_cache_action)
            end
          end

          context 'when enable_declarative_asset_downloads is true' do
            let(:enable_declarative_asset_downloads) { true }

            it 'returns the buildpack staging action without download actions' do
              result = builder.action

              serial_action = result.serial_action
              actions       = serial_action.actions

              expect(actions[0].parallel_action).to be_nil
            end

            context 'when the app package does not have a sha256 checksum' do
              # this test can be removed once all app packages have sha256 checksums
              before do
                lifecycle_data[:app_bits_checksum][:type] = 'sha1'
                download_app_package_action['checksum_algorithm'] = 'sha1'
              end

              it 'includes the app package download in the staging action' do
                result = builder.action

                serial_action = result.serial_action
                actions       = serial_action.actions

                parallel_download_action = actions[0].parallel_action
                expect(parallel_download_action.actions.count).to eq(1)
                expect(parallel_download_action.actions[0].download_action).to eq(download_app_package_action)
              end
            end
          end

          context('when system-buildpacks are used') do
            let(:buildpacks) do
              [
                { name: 'node-cnb', key: 'node-key', skip_detect: false },
                { name: 'java-cnb', key: 'java-key', skip_detect: false }
              ]
            end

            before do
              lifecycle_data[:auto_detect] = true
            end

            let(:run_staging_action) do
              ::Diego::Bbs::Models::RunAction.new(
                path: '/tmp/lifecycle/builder',
                user: 'vcap',
                args: ['--cache-dir', '/tmp/cache', '--cache-output', '/tmp/cache-output.tgz', '--auto-detect', '--buildpack', 'node-key', '--buildpack',
                       'java-key', '--pass-env-var', 'FOO', '--pass-env-var', 'BAR'],
                env: bbs_env
              )
            end

            it 'returns the buildpack staging action without download actions' do
              result = builder.action

              serial_action = result.serial_action
              actions       = serial_action.actions

              expect(actions[1].run_action).to eq(run_staging_action)
              expect(builder.cached_dependencies).to include(::Diego::Bbs::Models::CachedDependency.new(
                                                               name: 'node-cnb',
                                                               from: '',
                                                               to: '/tmp/buildpacks/0dcf6bb539d77cbc',
                                                               cache_key: 'node-key',
                                                               log_source: '',
                                                               checksum_algorithm: '',
                                                               checksum_value: ''
                                                             ))
              expect(builder.cached_dependencies).to include(::Diego::Bbs::Models::CachedDependency.new(
                                                               name: 'java-cnb',
                                                               from: '',
                                                               to: '/tmp/buildpacks/be0ef1aa1092a6db',
                                                               cache_key: 'java-key',
                                                               log_source: '',
                                                               checksum_algorithm: '',
                                                               checksum_value: ''
                                                             ))
            end
          end
        end

        describe '#cached_dependencies' do
          it 'always returns the cnb lifecycle bundle dependency' do
            result = builder.cached_dependencies
            expect(result).to include(
              ::Diego::Bbs::Models::CachedDependency.new(
                from: 'generated-uri',
                to: '/tmp/lifecycle',
                cache_key: 'cnb-buildpack-stack-lifecycle'
              )
            )
          end
        end

        describe '#stack' do
          before do
            Stack.create(name: 'separate-build-and-run', run_rootfs_image: 'run-image', build_rootfs_image: 'build-image')
          end

          it 'returns the stack' do
            expect(builder.stack).to eq('preloaded:buildpack-stack')
          end

          context 'when the stack does not exist' do
            let(:stack) { 'does-not-exist' }

            it 'raises an error' do
              expect do
                builder.stack
              end.to raise_error CloudController::Errors::ApiError, /The stack could not be found/
            end
          end

          context 'when the stack has separate build and run rootfs images' do
            let(:stack) { 'separate-build-and-run' }

            it 'returns the build rootfs image' do
              expect(builder.stack).to eq('preloaded:build-image')
            end
          end
        end

        describe '#task_environment_variables' do
          it 'contains CNB_USER_ID' do
            user_env = ::Diego::Bbs::Models::EnvironmentVariable.new(name: 'CNB_USER_ID', value: '2000')
            expect(builder.task_environment_variables).to include(user_env)
          end

          it 'contains CNB_GROUP_ID' do
            group_env = ::Diego::Bbs::Models::EnvironmentVariable.new(name: 'CNB_GROUP_ID', value: '2000')
            expect(builder.task_environment_variables).to include(group_env)
          end

          it 'does not contain CNB_REGISTRY_CREDS' do
            builder.task_environment_variables.each do |env|
              expect(env.name).not_to eql('CNB_REGISTRY_CREDS')
            end
          end

          context 'when the lifecycle contains credentials' do
            let(:lifecycle_data) do
              {
                credentials: '{"registry":{"username":"password"}}'
              }
            end

            it 'contains CNB_REGISTRY_CREDS' do
              group_env = ::Diego::Bbs::Models::EnvironmentVariable.new(name: 'CNB_REGISTRY_CREDS', value: '{"registry":{"username":"password"}}')
              expect(builder.task_environment_variables).to include(group_env)
            end
          end
        end
      end
    end
  end
end
