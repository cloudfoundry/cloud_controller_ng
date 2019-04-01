require 'spec_helper'

module VCAP::CloudController
  module Diego
    module Buildpack
      RSpec.describe StagingActionBuilder do
        subject(:builder) { StagingActionBuilder.new(config, staging_details, lifecycle_data) }

        let(:droplet) { DropletModel.make(:buildpack) }
        let(:enable_declarative_asset_downloads) { false }
        let(:config) do
          Config.new({
            skip_cert_verify: false,
            diego:            {
              cc_uploader_url:   'http://cc-uploader.example.com',
              file_server_url:   'http://file-server.example.com',
              lifecycle_bundles: {
                'buildpack/buildpack-stack': 'the-buildpack-bundle'
              },
              enable_declarative_asset_downloads: enable_declarative_asset_downloads,
            },
            staging:          {
              minimum_staging_file_descriptor_limit: 4,
              timeout_in_seconds:                    90,
            },
          })
        end
        let(:staging_details) do
          StagingDetails.new.tap do |details|
            details.staging_guid          = droplet.guid
            details.environment_variables = env
          end
        end
        let(:env) { double(:env) }
        let(:lifecycle_data) do
          {
            app_bits_download_uri:              'http://app_bits_download_uri.example.com/path/to/bits',
            build_artifacts_cache_download_uri: 'http://build_artifacts_cache_download_uri.example.com/path/to/bits',
            build_artifacts_cache_upload_uri:   'http://build_artifacts_cache_upload_uri.example.com/path/to/bits',
            buildpacks:                         buildpacks,
            droplet_upload_uri:                 'http://droplet_upload_uri.example.com/path/to/bits',
            stack:                              'buildpack-stack',
            buildpack_cache_checksum:           'bp-cache-checksum',
            app_bits_checksum:                  { type: 'sha256', value: 'package-checksum' },
          }
        end
        let(:buildpacks) { [] }
        let(:generated_environment) { [::Diego::Bbs::Models::EnvironmentVariable.new(name: 'generated-environment', value: 'generated-value')] }

        before do
          allow(LifecycleBundleUriGenerator).to receive(:uri).with('the-buildpack-bundle').and_return('generated-uri')
          allow(BbsEnvironmentBuilder).to receive(:build).with(env).and_return(generated_environment)
          TestConfig.override(credhub_api: nil)
        end

        describe '#action' do
          let(:download_app_package_action) do
            ::Diego::Bbs::Models::DownloadAction.new(
              artifact:           'app package',
              from:               'http://app_bits_download_uri.example.com/path/to/bits',
              to:                 '/tmp/app',
              user:               'vcap',
              checksum_algorithm: 'sha256',
              checksum_value:     'package-checksum',
            )
          end

          let(:download_build_artifacts_cache_action) do
            ::Diego::Bbs::Models::DownloadAction.new(
              artifact:           'build artifacts cache',
              from:               'http://build_artifacts_cache_download_uri.example.com/path/to/bits',
              to:                 '/tmp/cache',
              user:               'vcap',
              checksum_algorithm: 'sha256',
              checksum_value:     'bp-cache-checksum'
            )
          end

          let(:droplet_upload_url) { CGI.escape('http://droplet_upload_uri.example.com/path/to/bits') }
          let(:upload_droplet_action) do
            ::Diego::Bbs::Models::UploadAction.new(
              artifact: 'droplet',
              from:     '/tmp/droplet',
              to:       "http://cc-uploader.example.com/v1/droplet/#{droplet.guid}?cc-droplet-upload-uri=#{droplet_upload_url}&timeout=90",
              user:     'vcap'
            )
          end

          let(:cache_upload_url) { CGI.escape('http://build_artifacts_cache_upload_uri.example.com/path/to/bits') }
          let(:upload_build_artifacts_cache_action) do
            ::Diego::Bbs::Models::UploadAction.new(
              artifact: 'build artifacts cache',
              from:     '/tmp/output-cache',
              to:       "http://cc-uploader.example.com/v1/build_artifacts/#{droplet.guid}?cc-build-artifacts-upload-uri=#{cache_upload_url}&timeout=90",
              user:     'vcap'
            )
          end

          let(:run_staging_action) do
            ::Diego::Bbs::Models::RunAction.new(
              path:            '/tmp/lifecycle/builder',
              args:            [
                '-buildpackOrder=buildpack-1-key,buildpack-2-key',
                '-skipCertVerify=false',
                '-skipDetect=false',
                '-buildDir=/tmp/app',
                '-outputDroplet=/tmp/droplet',
                '-outputMetadata=/tmp/result.json',
                '-outputBuildArtifactsCache=/tmp/output-cache',
                '-buildpacksDir=/tmp/buildpacks',
                '-buildArtifactsCacheDir=/tmp/cache',
              ],
              user:            'vcap',
              resource_limits: ::Diego::Bbs::Models::ResourceLimits.new(nofile: 4),
              env:             generated_environment,
            )
          end

          let(:buildpacks) do
            [
              { name: 'buildpack-1', key: 'buildpack-1-key', url: 'buildpack-1-url', skip_detect: false },
              { name: 'buildpack-2', key: 'buildpack-2-key', url: 'buildpack-2-url', skip_detect: false },
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
            expect(parallel_upload_action.parallel_action).to_not be_nil
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
              before do
                TestConfig.override(credhub_api: { internal_url: 'http:credhub.capi.land:8844' })
              end

              context 'when the interpolation of service bindings is enabled' do
                before do
                  TestConfig.override(credential_references: { interpolate_service_bindings: true })
                end

                it 'sends the credhub_url in the environment variables' do
                  result = builder.action
                  actions = result.serial_action.actions

                  expect(actions[1].run_action.env).to eq(generated_environment + expected_platform_options)
                end
              end

              context 'when the interpolation of service bindings is disabled' do
                before do
                  TestConfig.override(credential_references: { interpolate_service_bindings: false })
                end

                it 'does not send the credhub_url in the environment variables' do
                  result = builder.action
                  actions = result.serial_action.actions

                  expect(actions[1].run_action.env).to eq(generated_environment)
                end
              end
            end

            context 'when credhub url is not present' do
              before do
                TestConfig.override(credhub_api: nil)
              end

              it 'does not send the credhub_url in the environment variables' do
                result = builder.action
                actions = result.serial_action.actions
                expect(actions[1].run_action.env).to eq(generated_environment)
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

          context 'when any specified buildpack has "skip_detect" set to true' do
            let(:buildpacks) {
              [
                { name: 'buildpack-1', key: 'buildpack-1-key', url: 'buildpack-1-url', skip_detect: false },
                { name: 'buildpack-2', key: 'buildpack-2-key', url: 'buildpack-2-url', skip_detect: true },
              ]
            }

            it 'sets skipDetect to true' do
              result = builder.action

              serial_action = result.serial_action
              actions       = serial_action.actions

              expect(actions[1].run_action.args).to include('-skipDetect=true')
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
        end

        describe '#cached_dependencies' do
          it 'always returns the buildpack lifecycle bundle dependency' do
            result = builder.cached_dependencies
            expect(result).to include(
              ::Diego::Bbs::Models::CachedDependency.new(
                from:      'generated-uri',
                to:        '/tmp/lifecycle',
                cache_key: 'buildpack-buildpack-stack-lifecycle',
              )
            )
          end

          context 'when enable_declarative_asset_downloads is true' do
            let(:enable_declarative_asset_downloads) { true }

            it 'returns no cached dependencies' do
              expect(builder.cached_dependencies).to be_nil
            end
          end

          context 'when there are buildpacks' do
            let(:buildpacks) do
              [
                { name: 'buildpack-1', key: 'buildpack-1-key', url: 'buildpack-1-url', sha256: 'checksum' },
                { name: 'buildpack-2', key: 'buildpack-2-key', url: 'buildpack-2-url', sha256: 'checksum' },
              ]
            end

            it 'includes buildpack dependencies' do
              buildpack_entry_1 = ::Diego::Bbs::Models::CachedDependency.new(
                name:               'buildpack-1',
                from:               'buildpack-1-url',
                to:                 "/tmp/buildpacks/#{Digest::MD5.hexdigest('buildpack-1-key')}",
                cache_key:          'buildpack-1-key',
                checksum_algorithm: 'sha256',
                checksum_value:     'checksum',
              )
              buildpack_entry_2 = ::Diego::Bbs::Models::CachedDependency.new(
                name:               'buildpack-2',
                from:               'buildpack-2-url',
                to:                 "/tmp/buildpacks/#{Digest::MD5.hexdigest('buildpack-2-key')}",
                cache_key:          'buildpack-2-key',
                checksum_algorithm: 'sha256',
                checksum_value:     'checksum',
              )

              result = builder.cached_dependencies
              expect(result).to include(buildpack_entry_1, buildpack_entry_2)
            end

            context 'when enable_declarative_asset_downloads is true' do
              let(:enable_declarative_asset_downloads) { true }

              it 'returns no cached dependencies' do
                expect(builder.cached_dependencies).to be_nil
              end
            end

            context 'and some do not include checksums' do
              let(:buildpacks) do
                [
                  { name: 'buildpack-1', key: 'buildpack-1-key', url: 'buildpack-1-url', sha256: 'checksum' },
                  { name: 'buildpack-2', key: 'buildpack-2-key', url: 'buildpack-2-url', sha256: nil },
                ]
              end

              it 'does not ask for checksum validation' do
                buildpack_entry_1 = ::Diego::Bbs::Models::CachedDependency.new(
                  name:               'buildpack-1',
                  from:               'buildpack-1-url',
                  to:                 "/tmp/buildpacks/#{Digest::MD5.hexdigest('buildpack-1-key')}",
                  cache_key:          'buildpack-1-key',
                  checksum_algorithm: 'sha256',
                  checksum_value:     'checksum',
                )
                buildpack_entry_2 = ::Diego::Bbs::Models::CachedDependency.new(
                  name:      'buildpack-2',
                  from:      'buildpack-2-url',
                  to:        "/tmp/buildpacks/#{Digest::MD5.hexdigest('buildpack-2-key')}",
                  cache_key: 'buildpack-2-key',
                )

                result = builder.cached_dependencies
                expect(result).to include(buildpack_entry_1, buildpack_entry_2)
              end

              context 'when enable_declarative_asset_downloads is true' do
                let(:enable_declarative_asset_downloads) { true }

                it 'returns no cached dependencies' do
                  expect(builder.cached_dependencies).to be_nil
                end
              end
            end
          end

          context 'when there are custom buildpacks' do
            let(:buildpacks) do
              [
                { name: 'buildpack-1', key: 'buildpack-1-key', url: 'buildpack-1-url', sha256: 'checksum' },
                { name: 'custom', key: 'custom-key', url: 'custom-url' },
              ]
            end

            it 'does not include the custom buildpacks' do
              buildpack_entry_1 = ::Diego::Bbs::Models::CachedDependency.new(
                name:               'buildpack-1',
                from:               'buildpack-1-url',
                to:                 "/tmp/buildpacks/#{Digest::MD5.hexdigest('buildpack-1-key')}",
                cache_key:          'buildpack-1-key',
                checksum_algorithm: 'sha256',
                checksum_value:     'checksum',
              )
              buildpack_entry_2 = ::Diego::Bbs::Models::CachedDependency.new(
                name:      'custom',
                from:      'custom-url',
                to:        "/tmp/buildpacks/#{Digest::MD5.hexdigest('custom-key')}",
                cache_key: 'custom-key',
              )

              result = builder.cached_dependencies
              expect(result).to include(buildpack_entry_1)
              expect(result).not_to include(buildpack_entry_2)
            end
          end
        end

        describe '#image_layers' do
          it 'returns no image layers' do
            expect(builder.image_layers).to be_empty
          end

          context 'when enable_declarative_asset_downloads is true' do
            let(:enable_declarative_asset_downloads) { true }

            it 'returns the lifecycle as an image layer' do
              expect(builder.image_layers).to include(
                ::Diego::Bbs::Models::ImageLayer.new(
                  name:              'buildpack-buildpack-stack-lifecycle',
                  url:               'generated-uri',
                  destination_path:  '/tmp/lifecycle',
                  layer_type:        ::Diego::Bbs::Models::ImageLayer::Type::SHARED,
                  media_type:        ::Diego::Bbs::Models::ImageLayer::MediaType::TGZ,
                )
              )
            end

            it 'returns the app package as an image layer' do
              expect(builder.image_layers).to include(
                ::Diego::Bbs::Models::ImageLayer.new(
                  name:              'app package',
                  url:               'http://app_bits_download_uri.example.com/path/to/bits',
                  destination_path:  '/tmp/app',
                  layer_type:        ::Diego::Bbs::Models::ImageLayer::Type::EXCLUSIVE,
                  media_type:        ::Diego::Bbs::Models::ImageLayer::MediaType::ZIP,
                  digest_algorithm:  ::Diego::Bbs::Models::ImageLayer::DigestAlgorithm::SHA256,
                  digest_value:      'package-checksum',
                )
              )
            end

            context 'when the app package does not have sha256 checksum' do
              # this test can be removed once all app packages have sha256 checksums
              before do
                lifecycle_data[:app_bits_checksum][:type] = 'sha1'
              end

              it 'does not include the app package as an image layer' do
                expect(builder.image_layers.any? { |l| l['name'] == 'app package' }).to be false
              end
            end

            it 'returns the buildpack cache as an image layer' do
              expect(builder.image_layers).to include(
                ::Diego::Bbs::Models::ImageLayer.new(
                  name:              'build artifacts cache',
                  url:               'http://build_artifacts_cache_download_uri.example.com/path/to/bits',
                  destination_path:  '/tmp/cache',
                  layer_type:        ::Diego::Bbs::Models::ImageLayer::Type::EXCLUSIVE,
                  media_type:        ::Diego::Bbs::Models::ImageLayer::MediaType::ZIP,
                  digest_algorithm:  ::Diego::Bbs::Models::ImageLayer::DigestAlgorithm::SHA256,
                  digest_value:      'bp-cache-checksum',
                )
              )
            end

            context 'when there is no buildpack cache' do
              before do
                lifecycle_data[:build_artifacts_cache_download_uri] = nil
              end

              it 'does not include the buildpack cache as an image layer' do
                expect(builder.image_layers.any? { |l| l['name'] == 'build artifacts cache' }).to be false
              end
            end

            context 'when there is no buildpack cache checksum' do
              before do
                lifecycle_data[:buildpack_cache_checksum] = ''
              end

              it 'does not include the buildpack cache as an image layer' do
                expect(builder.image_layers.any? { |l| l['name'] == 'build artifacts cache' }).to be false
              end
            end

            context 'when there are buildpacks' do
              let(:buildpacks) do
                [
                  { name: 'buildpack-1', key: 'buildpack-1-key', url: 'buildpack-1-url', sha256: 'checksum' },
                  { name: 'buildpack-2', key: 'buildpack-2-key', url: 'buildpack-2-url', sha256: 'checksum' },
                ]
              end

              it 'returns the buildpacks as an image layer' do
                expect(builder.image_layers).to include(
                  ::Diego::Bbs::Models::ImageLayer.new(
                    name:              'buildpack-1',
                    url:               'buildpack-1-url',
                    destination_path:  "/tmp/buildpacks/#{Digest::MD5.hexdigest('buildpack-1-key')}",
                    digest_algorithm:  ::Diego::Bbs::Models::ImageLayer::DigestAlgorithm::SHA256,
                    digest_value:      'checksum',
                    layer_type:        ::Diego::Bbs::Models::ImageLayer::Type::SHARED,
                    media_type:        ::Diego::Bbs::Models::ImageLayer::MediaType::ZIP,
                  )
                )
                expect(builder.image_layers).to include(
                  ::Diego::Bbs::Models::ImageLayer.new(
                    name:              'buildpack-2',
                    url:               'buildpack-2-url',
                    destination_path:  "/tmp/buildpacks/#{Digest::MD5.hexdigest('buildpack-2-key')}",
                    digest_algorithm:  ::Diego::Bbs::Models::ImageLayer::DigestAlgorithm::SHA256,
                    digest_value:      'checksum',
                    layer_type:        ::Diego::Bbs::Models::ImageLayer::Type::SHARED,
                    media_type:        ::Diego::Bbs::Models::ImageLayer::MediaType::ZIP,
                  )
                )
              end

              context 'and some do not include checksums' do
                let(:buildpacks) do
                  [
                    { name: 'buildpack-1', key: 'buildpack-1-key', url: 'buildpack-1-url', sha256: 'checksum' },
                    { name: 'buildpack-2', key: 'buildpack-2-key', url: 'buildpack-2-url', sha256: nil },
                  ]
                end

                it 'returns the buildpacks without checksum information' do
                  expect(builder.image_layers).to include(
                    ::Diego::Bbs::Models::ImageLayer.new(
                      name:              'buildpack-2',
                      url:               'buildpack-2-url',
                      destination_path:  "/tmp/buildpacks/#{Digest::MD5.hexdigest('buildpack-2-key')}",
                      layer_type:        ::Diego::Bbs::Models::ImageLayer::Type::SHARED,
                      media_type:        ::Diego::Bbs::Models::ImageLayer::MediaType::ZIP,
                    )
                  )
                end
              end
            end

            context 'when there are custom buildpacks' do
              let(:buildpacks) do
                [
                  { name: 'buildpack-1', key: 'buildpack-1-key', url: 'buildpack-1-url', sha256: 'checksum' },
                  { name: 'custom', key: 'custom-key', url: 'custom-url' },
                ]
              end

              it 'does not returns the custom buildpack as an image layer' do
                expect(builder.image_layers).not_to include(
                  ::Diego::Bbs::Models::ImageLayer.new(
                    name:              'custom',
                    url:               'custom-url',
                    destination_path:  "/tmp/buildpacks/#{Digest::MD5.hexdigest('custom-key')}",
                    layer_type:        ::Diego::Bbs::Models::ImageLayer::Type::SHARED,
                    media_type:        ::Diego::Bbs::Models::ImageLayer::MediaType::ZIP,
                  )
                )
              end
            end
          end
        end

        describe '#stack' do
          it 'returns the stack' do
            expect(builder.stack).to eq('buildpack-stack')
          end
        end

        describe '#task_environment_variables' do
          it 'returns LANG' do
            lang_env = ::Diego::Bbs::Models::EnvironmentVariable.new(name: 'LANG', value: 'en_US.UTF-8')
            expect(builder.task_environment_variables).to match_array([lang_env])
          end
        end
      end
    end
  end
end
