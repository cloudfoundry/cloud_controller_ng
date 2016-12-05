require 'spec_helper'

module VCAP::CloudController
  module Diego
    module Buildpack
      RSpec.describe DesiredLrpBuilder do
        subject(:builder) { described_class.new(config, app_request) }
        let(:app_request) do
          {
            'stack' => 'potato-stack',
            'droplet_uri' => 'droplet-uri',
            'droplet_hash' => 'droplet-hash',
            'process_guid' => 'p-guid',
            'ports' => ports,
          }
        end
        let(:ports) { [1111, 2222, 3333] }
        let(:config) do
          {
            diego: {
              file_server_url: 'http://file-server.example.com',
              lifecycle_bundles: {
                'buildpack/potato-stack': '/path/to/lifecycle.tgz',
              },
              use_privileged_containers_for_running: use_privileged_containers_for_running,
            }
          }
        end
        let(:use_privileged_containers_for_running) { false }

        describe '#root_fs' do
          it 'returns a constructed root_fs' do
            expect(builder.root_fs).to eq('preloaded:potato-stack')
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
                        from: 'droplet-uri',
                        cache_key: 'droplets-p-guid',
                        checksum_algorithm: 'sha1',
                        checksum_value: 'droplet-hash',
                      )
                    )
                  ],
                )
              )
            )
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
              config[:diego][:use_privileged_containers_for_running] = true
            end

            it 'returns true' do
              expect(builder.privileged?).to eq(true)
            end
          end

          context 'when the config is false' do
            before do
              config[:diego][:use_privileged_containers_for_running] = false
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
            let(:ports) { nil }

            it 'returns an array of the default' do
              expect(builder.ports).to eq([DEFAULT_APP_PORT])
            end
          end

          xcontext 'when the ports array is empty'
        end
      end
    end
  end
end
