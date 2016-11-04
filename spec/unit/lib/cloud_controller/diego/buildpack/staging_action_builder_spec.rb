require 'spec_helper'

module VCAP::CloudController
  module Diego
    module Buildpack
      RSpec.describe StagingActionBuilder do
        subject(:builder) { described_class.new(config, staging_details, lifecycle_data) }

        let(:droplet) { DropletModel.make(:buildpack) }
        let(:config) do
          {
            skip_cert_verify: false,
            diego:            {
              cc_uploader_url:   'http://cc-uploader.example.com',
              file_server_url:   'http://file-server.example.com',
              lifecycle_bundles: {
                'buildpack/buildpack-stack': 'the-buildpack-bundle'
              },
            },
            staging:          {
              minimum_staging_file_descriptor_limit: 4,
              timeout_in_seconds:                    90,
            },
          }
        end
        let(:staging_details) do
          StagingDetails.new.tap do |details|
            details.droplet               = droplet
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
          }
        end
        let(:buildpacks) { [] }

        before do
          allow(LifecycleBundleUriGenerator).to receive(:uri).with('the-buildpack-bundle').and_return('generated-uri')
          allow(BbsEnvironmentBuilder).to receive(:build).with(env).and_return('generated-environment')
        end

        describe '#action' do
          let(:download_app_package_action) do
            ::Diego::Bbs::Models::DownloadAction.new(
              artifact: 'app package',
              from:     'http://app_bits_download_uri.example.com/path/to/bits',
              to:       '/tmp/app',
              user:     'vcap'
            )
          end

          let(:download_build_artifacts_cache_action) do
            ::Diego::Bbs::Models::DownloadAction.new(
              artifact: 'build artifacts cache',
              from:     'http://build_artifacts_cache_download_uri.example.com/path/to/bits',
              to:       '/tmp/cache',
              user:     'vcap'
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
                '-skipDetect=false'
              ],
              user:            'vcap',
              resource_limits: ::Diego::Bbs::Models::ResourceLimits.new(nofile: 4),
              env:             'generated-environment',
            )
          end

          let(:buildpacks) do
            [
              { name: 'buildpack-1', key: 'buildpack-1-key', url: 'buildpack-1-url', skip_detect: false },
              { name: 'buildpack-2', key: 'buildpack-2-key', url: 'buildpack-2-url', skip_detect: true },
            ]
          end

          it 'returns the correct docker staging action structure' do
            result = builder.action

            serial_action = result.serial_action
            actions       = serial_action.actions

            parallel_download_action = actions[0].parallel_action
            expect(parallel_download_action.actions[0].download_action).to eq(download_app_package_action)
            expect(parallel_download_action.actions[1].download_action).to eq(download_build_artifacts_cache_action)

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

          context 'when there is a specific buildpack requested' do
            let(:buildpacks) {
              [
                { name: 'buildpack-1', key: 'buildpack-1-key', url: 'buildpack-1-url', skip_detect: true },
              ]
            }

            it 'sets skipDetect to true' do
              result = builder.action

              serial_action = result.serial_action
              actions       = serial_action.actions

              expect(actions[1].run_action.args).to include('-skipDetect=true')
            end
          end
        end

        describe '#cached_dependencies' do
          it 'always returns the builpdack lifecycle bundle dependency' do
            result = builder.cached_dependencies
            expect(result).to include(
              ::Diego::Bbs::Models::CachedDependency.new(
                from:      'generated-uri',
                to:        '/tmp/lifecycle',
                cache_key: 'buildpack-buildpack-stack-lifecycle',
              )
            )
          end

          context 'when there are buildpacks' do
            let(:buildpacks) do
              [
                { name: 'buildpack-1', key: 'buildpack-1-key', url: 'buildpack-1-url', skip_detect: false },
                { name: 'buildpack-2', key: 'buildpack-2-key', url: 'buildpack-2-url', skip_detect: true },
              ]
            end

            it 'includes buildpack dependencies' do
              buildpack_entry_1 = ::Diego::Bbs::Models::CachedDependency.new(
                name:      'buildpack-1',
                from:      'buildpack-1-url',
                to:        "/tmp/buildpacks/#{Digest::MD5.hexdigest('buildpack-1-key')}",
                cache_key: 'buildpack-1-key',
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
          end

          context 'when there are custom buildpacks' do
            let(:buildpacks) do
              [
                { name: 'buildpack-1', key: 'buildpack-1-key', url: 'buildpack-1-url', skip_detect: false },
                { name: 'custom', key: 'custom-key', url: 'custom-url', skip_detect: true },
              ]
            end

            it 'does not include the custom buildpacks' do
              buildpack_entry_1 = ::Diego::Bbs::Models::CachedDependency.new(
                name:      'buildpack-1',
                from:      'buildpack-1-url',
                to:        "/tmp/buildpacks/#{Digest::MD5.hexdigest('buildpack-1-key')}",
                cache_key: 'buildpack-1-key',
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
