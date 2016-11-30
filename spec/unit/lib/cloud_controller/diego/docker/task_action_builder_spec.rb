require 'spec_helper'
require 'cloud_controller/diego/buildpack/task_action_builder'

module VCAP::CloudController
  module Diego
    module Docker
      RSpec.describe TaskActionBuilder do
        subject(:task_action_builder) { described_class.new(config, task, lifecycle_data) }

        let(:config) do
          {
            diego: {
              lifecycle_bundles: {
                docker: 'http://file-server.com/v1/static/the/docker/lifecycle/path.tgz'
              }
            }
          }
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
        let(:environment_json) { { RIZ: 'shirt' }.to_json }
        before do
          VCAP::CloudController::EnvironmentVariableGroup.running.update(environment_json: environment_json)
          task_environment = instance_double(VCAP::CloudController::Diego::TaskEnvironment)
          allow(task_environment).to receive(:build).and_return(
            { 'VCAP_APPLICATION' => { greg: 'pants' }, 'MEMORY_LIMIT' => '256m', 'VCAP_SERVICES' => {} }
          )
          allow(VCAP::CloudController::Diego::TaskEnvironment).to receive(:new).and_return(task_environment)
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
        end

        describe '#task_environment_variables' do
          it 'returns task environment variables' do
            expect(task_action_builder.task_environment_variables).to match_array([
              ::Diego::Bbs::Models::EnvironmentVariable.new(name: 'VCAP_APPLICATION', value: '{"greg":"pants"}'),
              ::Diego::Bbs::Models::EnvironmentVariable.new(name: 'MEMORY_LIMIT', value: '256m'),
              ::Diego::Bbs::Models::EnvironmentVariable.new(name: 'VCAP_SERVICES', value: '{}')
            ])
            expect(VCAP::CloudController::Diego::TaskEnvironment).to have_received(:new).with(task.app, task, task.app.space, environment_json)
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
            let(:config) { { diego: { lifecycle_bundles: {} } } }

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
