require 'spec_helper'

module VCAP::CloudController
  module Diego
    module Buildpack
      RSpec.describe DesiredLrpBuilder do
        subject(:builder) {DesiredLrpBuilder.new(config, opts)}
        let(:stack) {'potato-stack'}
        let(:opts) do
          {
            stack: stack,
            droplet_uri: 'http://droplet-uri.com:1234?token=&@home--->',
            droplet_hash: 'droplet-hash',
            process_guid: 'p-guid',
            ports: ports,
            checksum_algorithm: 'checksum-algorithm',
            checksum_value: 'checksum-value',
            start_command: 'dd if=/dev/random of=/dev/null',
          }
        end
        let(:ports) {[1111, 2222, 3333]}
        let(:config) do
          Config.new({
            diego: {
              file_server_url: 'http://file-server.example.com',
              lifecycle_bundles: {
                'buildpack/potato-stack': '/path/to/lifecycle.tgz',
              },
              use_privileged_containers_for_running: use_privileged_containers_for_running,
              temporary_oci_buildpack_mode: temporary_oci_buildpack_mode,
            }
          })
        end
        let(:use_privileged_containers_for_running) {false}
        let(:temporary_oci_buildpack_mode) {''}

        describe '#start_command' do
          it 'returns the passed in start command' do
            expect(builder.start_command).to eq('dd if=/dev/random of=/dev/null')
          end
        end

        describe '#root_fs' do
          it 'returns a constructed root_fs' do
            expect(builder.root_fs).to eq('preloaded:potato-stack')
          end

          context 'when temporary_oci_buildpack_mode is set to oci-phase-1' do
            let(:temporary_oci_buildpack_mode) {'oci-phase-1'}

            it 'returns a constructed root_fs + layer URI' do
              expect(builder.root_fs).to eq('preloaded+layer:potato-stack?layer=http://droplet-uri.com:1234?token=&%40home---%3E&layer_path=/home/vcap&layer_digest=checksum-value')
            end
          end
        end

        describe '#cached_dependencies' do
          before do
            allow(LifecycleBundleUriGenerator).to receive(:uri).and_return('foo://bar.baz')
          end

          it 'returns an array of CachedDependency objects' do
            expect(builder.cached_dependencies).to eq([
              ::Diego::Bbs::Models::CachedDependency.new(
                from: 'foo://bar.baz',
                to: '/tmp/lifecycle',
                cache_key: 'buildpack-potato-stack-lifecycle',
              )
            ])
            expect(LifecycleBundleUriGenerator).to have_received(:uri).with('/path/to/lifecycle.tgz')
          end

          context 'when searching for a nonexistant stack' do
            let(:stack) {'stack-thats-not-in-config'}
            it 'errors nicely' do
              expect {builder.cached_dependencies}.to raise_error("no compiler defined for requested stack 'stack-thats-not-in-config'")
            end
          end
        end

        describe '#setup' do
          it 'creates a setup action to download the droplet' do
            expect(builder.setup).to eq(
              ::Diego::Bbs::Models::Action.new(
                serial_action: ::Diego::Bbs::Models::SerialAction.new(
                  actions: [
                    ::Diego::Bbs::Models::Action.new(
                      download_action: ::Diego::Bbs::Models::DownloadAction.new(
                        to: '.',
                        user: 'vcap',
                        from: 'http://droplet-uri.com:1234?token=&@home--->',
                        cache_key: 'droplets-p-guid',
                        checksum_algorithm: 'checksum-algorithm',
                        checksum_value: 'checksum-value',
                      )
                    )
                  ],
                )
              )
            )
          end

          context 'when temporary_oci_buildpack_mode is set to oci-phase-1' do
            let(:temporary_oci_buildpack_mode) {'oci-phase-1'}

            it 'returns nil' do
              expect(builder.setup).to be_nil
            end
          end
        end

        describe '#global_environment_variables' do
          it 'returns a list' do
            expect(builder.global_environment_variables).to match_array(
              [::Diego::Bbs::Models::EnvironmentVariable.new(name: 'LANG', value: DEFAULT_LANG)]
            )
          end
        end

        describe '#privileged?' do
          context 'when the config is true' do
            before do
              config.set(:diego, config.get(:diego).merge(use_privileged_containers_for_running: true))
            end

            it 'returns true' do
              expect(builder.privileged?).to eq(true)
            end
          end

          context 'when the config is false' do
            before do
              config.set(:diego, config.get(:diego).merge(use_privileged_containers_for_running: false))
            end

            it 'returns false' do
              expect(builder.privileged?).to eq(false)
            end
          end
        end

        describe '#ports' do
          it 'returns the ports array' do
            expect(builder.ports).to eq([1111, 2222, 3333])
          end

          context 'when the ports array is nil' do
            let(:ports) {nil}

            it 'returns an array of the default' do
              expect(builder.ports).to eq([DEFAULT_APP_PORT])
            end
          end

          xcontext 'when the ports array is empty'
        end

        describe '#port_environment_variables' do
          let(:ports) {[11, 22, 33]}

          it 'returns the array of environment variables' do
            expect(builder.port_environment_variables).to match_array([
              ::Diego::Bbs::Models::EnvironmentVariable.new(name: 'PORT', value: '11'),
              ::Diego::Bbs::Models::EnvironmentVariable.new(name: 'VCAP_APP_PORT', value: '11'),
              ::Diego::Bbs::Models::EnvironmentVariable.new(name: 'VCAP_APP_HOST', value: '0.0.0.0'),
            ])
          end
        end

        describe '#platform_options' do
          context 'when the app has a credhub url' do
            let(:expected_credhub_url) do
              "{\"credhub-uri\":\"#{TestConfig.config_instance.get(:credhub_api, :internal_url)}\"}"
            end

            before do
              TestConfig.override(credhub_api: {internal_url: 'http:credhub.capi.land:8844'})
            end

            context 'when the interpolation of service bindings is enabled' do
              before do
                TestConfig.override(credential_references: {interpolate_service_bindings: true})
              end

              it 'includes the credhub uri as part of the VCAP_PLATFORM_OPTIONS variable' do
                expect(builder.platform_options).to match_array([
                  ::Diego::Bbs::Models::EnvironmentVariable.new(name: 'VCAP_PLATFORM_OPTIONS', value: expected_credhub_url)
                ])
              end
            end

            context 'when the interpolation of service bindings is disabled' do
              before do
                TestConfig.override(credential_references: {interpolate_service_bindings: false})
              end

              it 'does not include the VCAP_PLATFORM_OPTIONS' do
                expect(builder.platform_options).to eq([])
              end
            end
          end

          context 'when the app does not have a credhub url' do
            before do
              TestConfig.override(credhub_api: nil)
            end

            it 'does not include the VCAP_PLATFORM_OPTIONS' do
              expect(builder.platform_options).to eq([])
            end
          end
        end
      end
    end
  end
end
