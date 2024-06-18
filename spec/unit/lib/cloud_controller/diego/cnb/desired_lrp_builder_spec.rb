require 'spec_helper'

module VCAP::CloudController
  module Diego
    module CNB
      RSpec.describe DesiredLrpBuilder do
        subject(:builder) { DesiredLrpBuilder.new(config, opts) }
        before do
          Stack.create(name: 'potato-stack')
          Stack.create(name: 'stack-thats-not-in-config')
        end

        let(:stack) { 'potato-stack' }
        let(:opts) do
          {
            stack: stack,
            droplet_uri: 'http://droplet-uri.com:1234?token=&@home--->',
            droplet_hash: 'droplet-hash',
            process_guid: 'p-guid',
            ports: ports,
            checksum_algorithm: 'checksum-algorithm',
            checksum_value: 'checksum-value',
            start_command: 'dd if=/dev/random of=/dev/null'
          }
        end
        let(:ports) { [1111, 2222, 3333] }
        let(:config) do
          Config.new({
                       diego: {
                         file_server_url: 'http://file-server.example.com',
                         lifecycle_bundles: lifecycle_bundles,
                         droplet_destinations: droplet_destinations,
                         use_privileged_containers_for_running: use_privileged_containers_for_running,
                         enable_declarative_asset_downloads: enable_declarative_asset_downloads
                       }
                     })
        end
        let(:lifecycle_bundles) do
          { "cnb/#{stack}": '/path/to/lifecycle.tgz' }
        end
        let(:droplet_destinations) do
          { stack.to_sym => '/value/from/config/based/on/stack' }
        end
        let(:use_privileged_containers_for_running) { false }
        let(:enable_declarative_asset_downloads) { false }

        describe '#start_command' do
          it 'returns the passed in start command' do
            expect(builder.start_command).to eq('dd if=/dev/random of=/dev/null')
          end
        end

        describe '#root_fs' do
          it 'returns a constructed root_fs' do
            expect(builder.root_fs).to eq('preloaded:potato-stack')
          end

          context 'when enable_declarative_asset_downloads is true' do
            let(:enable_declarative_asset_downloads) { true }

            it 'returns a constructed root_fs' do
              expect(builder.root_fs).to eq('preloaded:potato-stack')
            end
          end

          context 'when the stack does not exist' do
            let(:stack) { 'does-not-exist' }

            it 'raises an error' do
              expect do
                builder.root_fs
              end.to raise_error CloudController::Errors::ApiError, /The stack could not be found/
            end
          end

          context 'when the stack has separate run and build root_fs images' do
            let(:stack) { 'two-images-stack' }

            before do
              Stack.create(
                name: stack,
                description: 'a stack with separate build and run rootfses',
                run_rootfs_image: 'run-image',
                build_rootfs_image: 'build-image'
              )
            end

            it 'returns the run root_fs' do
              expect(builder.root_fs).to eq('preloaded:run-image')
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
                cache_key: 'cnb-potato-stack-lifecycle'
              )
            ])
            expect(LifecycleBundleUriGenerator).to have_received(:uri).with('/path/to/lifecycle.tgz')
          end

          context 'when searching for a nonexistant stack' do
            let(:lifecycle_bundles) do
              { 'hot-potato': '/path/to/lifecycle.tgz' }
            end
            let(:stack) { 'stack-thats-not-in-config' }

            it 'errors nicely' do
              expect { builder.cached_dependencies }.to raise_error("no compiler defined for requested stack 'stack-thats-not-in-config'")
            end
          end

          context 'when enable_declarative_asset_downloads is true' do
            let(:enable_declarative_asset_downloads) { true }

            it 'returns nil' do
              expect(builder.cached_dependencies).to be_nil
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
                        artifact: 'droplet',
                        to: '.',
                        user: 'vcap',
                        from: 'http://droplet-uri.com:1234?token=&@home--->',
                        cache_key: 'droplets-p-guid',
                        checksum_algorithm: 'checksum-algorithm',
                        checksum_value: 'checksum-value'
                      )
                    )
                  ]
                )
              )
            )
          end

          context 'when enable_declarative_asset_downloads is true' do
            let(:enable_declarative_asset_downloads) { true }

            context 'and the droplet does not have a sha256 checksum (it is a legacy droplet with a sha1 checksum)' do
              # this test can be removed once legacy sha1 checksummed droplets are obsolete
              let(:opts) { super().merge(checksum_algorithm: 'sha1') }

              it 'creates a setup action to download the droplet' do
                expect(builder.setup).to eq(
                  ::Diego::Bbs::Models::Action.new(
                    serial_action: ::Diego::Bbs::Models::SerialAction.new(
                      actions: [
                        ::Diego::Bbs::Models::Action.new(
                          download_action: ::Diego::Bbs::Models::DownloadAction.new(
                            artifact: 'droplet',
                            to: '.',
                            user: 'vcap',
                            from: 'http://droplet-uri.com:1234?token=&@home--->',
                            cache_key: 'droplets-p-guid',
                            checksum_algorithm: 'sha1',
                            checksum_value: 'checksum-value'
                          )
                        )
                      ]
                    )
                  )
                )
              end
            end

            context 'when checksum is sha256' do
              let(:opts) { super().merge(checksum_algorithm: 'sha256') }

              it 'returns nil' do
                expect(builder.setup).to be_nil
              end
            end
          end
        end

        describe '#image_layers' do
          before do
            allow(LifecycleBundleUriGenerator).to receive(:uri).and_return('foo://bar.baz')
          end

          it 'returns empty array' do
            expect(builder.image_layers).to be_empty
          end

          context 'when enable_declarative_asset_downloads is true' do
            let(:enable_declarative_asset_downloads) { true }

            context 'and the droplet does not have a sha256 checksum (it is a legacy droplet with a sha1 checksum)' do
              # this test can be removed once legacy sha1 checksummed droplets are obsolete
              let(:opts) { super().merge(checksum_algorithm: 'sha1') }

              it 'creates a image layer for each cached dependency' do
                expect(builder.image_layers).to eq([
                  ::Diego::Bbs::Models::ImageLayer.new(
                    name: 'cnb-potato-stack-lifecycle',
                    url: 'foo://bar.baz',
                    destination_path: '/tmp/lifecycle',
                    layer_type: ::Diego::Bbs::Models::ImageLayer::Type::SHARED,
                    media_type: ::Diego::Bbs::Models::ImageLayer::MediaType::TGZ
                  )
                ])
              end
            end

            context 'and the droplet has a sha256 checksum' do
              let(:opts) { super().merge(checksum_algorithm: 'sha256') }

              it 'creates a image layer for each cached dependency' do
                expect(builder.image_layers).to include(
                  ::Diego::Bbs::Models::ImageLayer.new(
                    name: 'cnb-potato-stack-lifecycle',
                    url: 'foo://bar.baz',
                    destination_path: '/tmp/lifecycle',
                    layer_type: ::Diego::Bbs::Models::ImageLayer::Type::SHARED,
                    media_type: ::Diego::Bbs::Models::ImageLayer::MediaType::TGZ
                  )
                )
              end

              it 'creates a image layer for the droplet' do
                expect(builder.image_layers).to include(
                  ::Diego::Bbs::Models::ImageLayer.new(
                    name: 'droplet',
                    url: 'http://droplet-uri.com:1234?token=&%40home---%3E',
                    destination_path: '/value/from/config/based/on/stack',
                    layer_type: ::Diego::Bbs::Models::ImageLayer::Type::EXCLUSIVE,
                    media_type: ::Diego::Bbs::Models::ImageLayer::MediaType::TGZ,
                    digest_value: 'checksum-value',
                    digest_algorithm: ::Diego::Bbs::Models::ImageLayer::DigestAlgorithm::SHA256
                  )
                )
              end

              context "when searching for a lifecycle associated with a stack that is not configured in the Cloud Controller's lifecycle_bundles config" do
                let(:lifecycle_bundles) do
                  { 'hot-potato': '/path/to/lifecycle.tgz' }
                end
                let(:stack) { 'stack-thats-not-in-config' }

                it 'errors nicely' do
                  expect { builder.image_layers }.to raise_error("no compiler defined for requested stack 'stack-thats-not-in-config'")
                end
              end

              context "when searching for a droplet destination associated with a stack that is not configured in the Cloud Controller's droplet_destinations config" do
                let(:droplet_destinations) do
                  { 'hot-potato': '/value/from/config/based/on/stack' }
                end
                let(:stack) { 'stack-thats-not-in-config' }

                it 'errors nicely' do
                  expect { builder.image_layers }.to raise_error("no droplet destination defined for requested stack 'stack-thats-not-in-config'")
                end
              end
            end
          end
        end

        describe '#global_environment_variables' do
          it 'returns a list' do
            expect(builder.global_environment_variables).to contain_exactly(::Diego::Bbs::Models::EnvironmentVariable.new(name: 'LANG', value: DEFAULT_LANG),
                                                                            ::Diego::Bbs::Models::EnvironmentVariable.new(name: 'CNB_LAYERS_DIR', value: '/home/vcap/layers'),
                                                                            ::Diego::Bbs::Models::EnvironmentVariable.new(name: 'CNB_APP_DIR', value: '/home/vcap/workspace'))
          end
        end

        describe '#privileged?' do
          context 'when the config is true' do
            before do
              config.set(:diego, config.get(:diego).merge(use_privileged_containers_for_running: true))
            end

            it 'returns true' do
              expect(builder.privileged?).to be(true)
            end
          end

          context 'when the config is false' do
            before do
              config.set(:diego, config.get(:diego).merge(use_privileged_containers_for_running: false))
            end

            it 'returns false' do
              expect(builder.privileged?).to be(false)
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

          context 'when the ports array is empty' do
            let(:ports) { [] }

            it 'returns an array of the default' do
              expect(builder.ports).to eq([DEFAULT_APP_PORT])
            end
          end
        end

        describe '#port_environment_variables' do
          let(:ports) { [11, 22, 33] }

          it 'returns the array of environment variables' do
            env_var1 = ::Diego::Bbs::Models::EnvironmentVariable.new(name: 'PORT', value: '11')
            expected_env_vars = [env_var1]

            expect(builder.port_environment_variables).to match_array(expected_env_vars)
          end
        end
      end
    end
  end
end
