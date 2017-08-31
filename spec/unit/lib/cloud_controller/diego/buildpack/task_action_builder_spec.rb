require 'spec_helper'

module VCAP::CloudController
  module Diego
    module Buildpack
      RSpec.describe TaskActionBuilder do
        subject(:builder) { TaskActionBuilder.new(config, task, lifecycle_data) }

        let(:config) do
          Config.new({
            diego: {
              lifecycle_bundles: {
                'buildpack/potato-stack': 'http://file-server.service.cf.internal:8080/v1/static/potato_lifecycle_bundle_url'
              }
            }
          })
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
