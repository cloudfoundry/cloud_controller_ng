require 'spec_helper'

module VCAP::CloudController
  module Diego
    module Docker
      RSpec.describe TaskActionBuilder do
        subject(:task_action_builder) { TaskActionBuilder.new(config, task, lifecycle_data) }

        let(:config) do
          Config.new({
            diego: {
              lifecycle_bundles: {
                docker: 'http://file-server.com/v1/static/the/docker/lifecycle/path.tgz'
              }
            }
          })
        end

        let(:task) { TaskModel.make command: command, name: 'my-task' }
        let(:lifecycle_data) do
          {
            droplet_path: 'user/image',
          }
        end

        let(:command) { 'echo "hello"' }
        let(:generated_environment) do
          [
            ::Diego::Bbs::Models::EnvironmentVariable.new(name: 'VCAP_APPLICATION', value: '{"greg":"pants"}'),
            ::Diego::Bbs::Models::EnvironmentVariable.new(name: 'MEMORY_LIMIT', value: '256m'),
            ::Diego::Bbs::Models::EnvironmentVariable.new(name: 'VCAP_SERVICES', value: '{}'),
          ]
        end

        before do
          allow(VCAP::CloudController::Diego::TaskEnvironmentVariableCollector).to receive(:for_task).and_return(generated_environment)
          TestConfig.override(credhub_api: nil)
        end

        describe '#action' do
          let(:run_task_action) do
            ::Diego::Bbs::Models::RunAction.new(
              user:            'root',
              path:            '/tmp/lifecycle/launcher',
              args:            ['app', command, '{}'],
              log_source:      'APP/TASK/my-task',
              resource_limits: ::Diego::Bbs::Models::ResourceLimits.new,
              env:             generated_environment,
            )
          end

          it 'returns the correct run action' do
            result = task_action_builder.action
            expect(result.run_action).to eq(run_task_action)
          end

          describe 'credhub' do
            context 'when credhub url is present' do
              let(:expected_credhub_url) do
                Base64.encode64("{\"credhub-uri\":\"#{TestConfig.config_instance.get(:credhub_api, :url)}\"}")
              end
              let(:run_task_action) do
                ::Diego::Bbs::Models::RunAction.new(
                  user:            'root',
                  path:            '/tmp/lifecycle/launcher',
                  args:            ['app', command, '{}', expected_credhub_url],
                  log_source:      'APP/TASK/my-task',
                  resource_limits: ::Diego::Bbs::Models::ResourceLimits.new,
                  env:             generated_environment,
                )
              end

              before do
                TestConfig.override(credhub_api: { url: 'http:credhub.capi.land:8844' })
              end

              it 'sends the base64-encoded credhub url as an argument to the launcher' do
                result = task_action_builder.action
                expect(result.run_action).to eq(run_task_action)
              end
            end

            context 'when credhub url is not present' do
              let(:run_task_action) do
                ::Diego::Bbs::Models::RunAction.new(
                  user:            'root',
                  path:            '/tmp/lifecycle/launcher',
                  args:            ['app', command, '{}'],
                  log_source:      'APP/TASK/my-task',
                  resource_limits: ::Diego::Bbs::Models::ResourceLimits.new,
                  env:             generated_environment,
                )
              end

              before do
                TestConfig.override(credhub_api: nil)
              end

              it 'does not include the credhub url' do
                result = task_action_builder.action
                expect(result.run_action).to eq(run_task_action)
              end
            end
          end
        end

        describe '#task_environment_variables' do
          it 'returns task environment variables' do
            expect(task_action_builder.task_environment_variables).to match_array(generated_environment)
            expect(VCAP::CloudController::Diego::TaskEnvironmentVariableCollector).to have_received(:for_task).with(task)
          end
        end

        describe '#stack' do
          it 'calls out to the DropletURIConverter' do
            expect(task_action_builder.stack).to eq('docker:///user/image')
          end

          context 'when the droplet path is invalid' do
            let(:lifecycle_data) { 'docker://invalid-docker-path' }

            it 'throws an error' do
              expect {
                task_action_builder.stack
              }.to raise_error(//)
            end
          end
        end

        describe '#cached_dependencies' do
          it 'returns a cached dependency for the correct lifecycle given the stack' do
            expect(task_action_builder.cached_dependencies).to eq([
              ::Diego::Bbs::Models::CachedDependency.new(
                from:      'http://file-server.com/v1/static/the/docker/lifecycle/path.tgz',
                to:        '/tmp/lifecycle',
                cache_key: 'docker-lifecycle',
              )
            ])
          end

          context 'when the requested stack is not in the configured lifecycle bundles' do
            let(:config) { Config.new({ diego: { lifecycle_bundles: {} } }) }

            it 'returns an error' do
              expect {
                task_action_builder.cached_dependencies
              }.to raise_error VCAP::CloudController::Diego::LifecycleBundleUriGenerator::InvalidStack
            end
          end
        end
      end
    end
  end
end
