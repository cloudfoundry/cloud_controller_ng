require 'spec_helper'

module VCAP::CloudController
  module Diego
    module Buildpack
      RSpec.describe TaskActionBuilder do
        subject(:builder) { TaskActionBuilder.new(config, task, lifecycle_data) }

        let(:enable_declarative_asset_downloads) { false }
        let(:config) do
          Config.new({
            diego: {
              enable_declarative_asset_downloads: enable_declarative_asset_downloads,
              lifecycle_bundles: {
                'buildpack/potato-stack': 'http://file-server.service.cf.internal:8080/v1/static/potato_lifecycle_bundle_url'
              },
              droplet_destinations: droplet_destinations,
            }
          })
        end
        let(:droplet_destinations) do
          { stack.to_sym => '/value/from/config/based/on/stack' }
        end
        let(:task) { TaskModel.make command: command, name: 'my-task' }
        let(:command) { 'echo "hello"' }

        let(:generated_environment) do
          [
            ::Diego::Bbs::Models::EnvironmentVariable.new(name: 'VCAP_APPLICATION', value: '{"greg":"pants"}'),
            ::Diego::Bbs::Models::EnvironmentVariable.new(name: 'MEMORY_LIMIT', value: '256m'),
            ::Diego::Bbs::Models::EnvironmentVariable.new(name: 'VCAP_SERVICES', value: '{}'),
          ]
        end

        let(:download_uri) { 'http://download_droplet.example.com' }
        let(:lifecycle_data) do
          {
            droplet_uri: download_uri,
            stack: stack
          }
        end
        let(:stack) { 'potato-stack' }

        before do
          allow(VCAP::CloudController::Diego::TaskEnvironmentVariableCollector).to receive(:for_task).and_return(generated_environment)
          TestConfig.override(credhub_api: nil)
        end

        describe '#action' do
          let(:download_app_droplet_action) do
            ::Diego::Bbs::Models::DownloadAction.new(
              from: download_uri,
              to: '.',
              cache_key: '',
              user: 'vcap',
              checksum_algorithm: 'sha256',
              checksum_value: task.droplet.sha256_checksum,
            )
          end

          let(:run_task_action) do
            ::Diego::Bbs::Models::RunAction.new(
              path:            '/tmp/lifecycle/launcher',
              args:            ['app', command, ''],
              log_source:      'APP/TASK/my-task',
              user:            'vcap',
              resource_limits: ::Diego::Bbs::Models::ResourceLimits.new,
              env:             generated_environment,
            )
          end

          it 'returns the correct buildpack task action structure' do
            result = builder.action

            serial_action = result.serial_action
            actions       = serial_action.actions

            expect(actions.length).to eq(2)
            expect(actions[0].download_action).to eq(download_app_droplet_action)
            expect(actions[1].run_action).to eq(run_task_action)
          end

          context 'when the droplet does not have a sha256 checksum calculated' do
            let(:download_app_droplet_action) do
              ::Diego::Bbs::Models::DownloadAction.new(
                from: download_uri,
                to: '.',
                cache_key: '',
                user: 'vcap',
                checksum_algorithm: 'sha1',
                checksum_value: task.droplet.droplet_hash,
              )
            end

            before do
              task.droplet.sha256_checksum = nil
              task.droplet.save
            end

            it 'uses sha1 in the download droplet action' do
              result = builder.action

              serial_action = result.serial_action
              actions       = serial_action.actions

              expect(actions.length).to eq(2)
              expect(actions[0].download_action).to eq(download_app_droplet_action)
            end
          end

          context 'when enable_declarative_asset_downloads is true' do
            let(:enable_declarative_asset_downloads) { true }

            it 'does not include the download step in the action' do
              result = builder.action
              expect(result.run_action).to eq(run_task_action)
            end

            context 'and the droplet does not have a sha256 checksum (it is a legacy droplet with a sha1 checksum)' do
              # this test can be removed once legacy sha1 checksummed droplets are obsolete
              let(:download_app_droplet_action) do
                ::Diego::Bbs::Models::DownloadAction.new(
                  from: download_uri,
                  to: '.',
                  cache_key: '',
                  user: 'vcap',
                  checksum_algorithm: 'sha1',
                  checksum_value: task.droplet.droplet_hash,
                )
              end

              before do
                task.droplet.sha256_checksum = nil
                task.droplet.save
              end

              it 'creates a action to download the droplet' do
                result = builder.action

                serial_action = result.serial_action
                actions       = serial_action.actions

                expect(actions.length).to eq(2)
                expect(actions[0].download_action).to eq(download_app_droplet_action)
                expect(actions[1].run_action).to eq(run_task_action)
              end
            end
          end
        end

        describe '#image_layers' do
          it 'returns empty array' do
            expect(builder.image_layers).to eq []
          end

          context 'when enable_declarative_asset_downloads is true' do
            let(:enable_declarative_asset_downloads) { true }

            context 'and the droplet does not have a sha256 checksum (it is a legacy droplet with a sha1 checksum)' do
              # this test can be removed once legacy sha1 checksummed droplets are obsolete
              before do
                task.droplet.sha256_checksum = nil
                task.droplet.save
              end

              it 'creates a image layer for each cached dependency' do
                expect(builder.image_layers).to eq([
                  ::Diego::Bbs::Models::ImageLayer.new(
                    name: 'buildpack-potato-stack-lifecycle',
                    url: 'http://file-server.service.cf.internal:8080/v1/static/potato_lifecycle_bundle_url',
                    destination_path: '/tmp/lifecycle',
                    layer_type: ::Diego::Bbs::Models::ImageLayer::Type::SHARED,
                    media_type: ::Diego::Bbs::Models::ImageLayer::MediaType::TGZ,
                  )
                ])
              end
            end

            it 'creates a image layer for each cached dependency' do
              expect(builder.image_layers).to include(
                ::Diego::Bbs::Models::ImageLayer.new(
                  name: 'buildpack-potato-stack-lifecycle',
                  url: 'http://file-server.service.cf.internal:8080/v1/static/potato_lifecycle_bundle_url',
                  destination_path: '/tmp/lifecycle',
                  layer_type: ::Diego::Bbs::Models::ImageLayer::Type::SHARED,
                  media_type: ::Diego::Bbs::Models::ImageLayer::MediaType::TGZ,
                )
              )
            end

            it 'creates a image layer for the droplet' do
              expect(builder.image_layers).to include(
                ::Diego::Bbs::Models::ImageLayer.new(
                  name: 'droplet',
                  url: lifecycle_data[:droplet_uri],
                  destination_path: '/value/from/config/based/on/stack',
                  layer_type: ::Diego::Bbs::Models::ImageLayer::Type::EXCLUSIVE,
                  media_type: ::Diego::Bbs::Models::ImageLayer::MediaType::TGZ,
                  digest_value: task.droplet.sha256_checksum,
                  digest_algorithm: ::Diego::Bbs::Models::ImageLayer::DigestAlgorithm::SHA256,
                )
              )
            end

            context 'when the requested stack is not in the configured lifecycle bundles' do
              let(:stack) { 'leek-stack' }

              it 'returns an error' do
                expect {
                  builder.image_layers
                }.to raise_error('no compiler defined for requested stack')
              end
            end

            context 'when the requested stack is not in the configured droplet destinations' do
              let(:stack) { 'leek-stack' }
              let(:droplet_destinations) do
                { 'yucca' => '/value/from/config/based/on/stack' }
              end

              it 'returns an error' do
                expect {
                  builder.image_layers
                }.to raise_error("no droplet destination defined for requested stack 'leek-stack'")
              end
            end
          end
        end

        describe '#task_environment_variables' do
          it 'returns task environment variables' do
            expect(builder.task_environment_variables).to match_array(generated_environment)
            expect(VCAP::CloudController::Diego::TaskEnvironmentVariableCollector).to have_received(:for_task).with(task)
          end
        end

        describe '#stack' do
          it 'returns the stack' do
            expect(builder.stack).to eq('preloaded:potato-stack')
          end
        end

        describe '#cached_dependencies' do
          it 'returns a cached dependency for the correct lifecycle given the stack' do
            expect(builder.cached_dependencies).to eq([
              ::Diego::Bbs::Models::CachedDependency.new(
                from:      'http://file-server.service.cf.internal:8080/v1/static/potato_lifecycle_bundle_url',
                to:        '/tmp/lifecycle',
                cache_key: 'buildpack-potato-stack-lifecycle',
              )
            ])
          end

          context 'when enable_declarative_asset_downloads is true' do
            let(:enable_declarative_asset_downloads) { true }

            it 'returns nil' do
              expect(builder.cached_dependencies).to be_nil
            end
          end

          context 'when the requested stack is not in the configured lifecycle bundles' do
            let(:stack) { 'leek-stack' }

            it 'returns an error' do
              expect {
                builder.cached_dependencies
              }.to raise_error VCAP::CloudController::Diego::LifecycleBundleUriGenerator::InvalidStack
            end
          end
        end
      end
    end
  end
end
