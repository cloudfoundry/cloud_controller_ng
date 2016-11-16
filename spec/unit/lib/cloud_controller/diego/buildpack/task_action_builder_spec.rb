require 'spec_helper'
require 'cloud_controller/diego/buildpack/task_action_builder'

module VCAP::CloudController
  module Diego
    module Buildpack
      RSpec.describe TaskActionBuilder do
        subject(:builder) { described_class.new(config, task, lifecycle_data) }

        let(:config) do
          {
            diego: {
              lifecycle_bundles: {
                'buildpack/potato-stack': 'http://file-server.service.cf.internal:8080/v1/static/potato_lifecycle_bundle_url'
              }
            }
          }
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

        let(:environment_json) { { RIZ: 'shirt' }.to_json }
        let(:download_uri) { 'http://download_droplet.example.com' }
        let(:lifecycle_data) do
          {
            droplet_uri: download_uri,
            stack: stack
          }
        end
        let(:stack) { 'potato-stack' }

        before do
          VCAP::CloudController::EnvironmentVariableGroup.running.update(environment_json: environment_json)
          task_environment = instance_double(VCAP::CloudController::Diego::TaskEnvironment)
          allow(task_environment).to receive(:build).and_return(
            { 'VCAP_APPLICATION' => { greg: 'pants' }, 'MEMORY_LIMIT' => '256m', 'VCAP_SERVICES' => {} }
          )
          allow(VCAP::CloudController::Diego::TaskEnvironment).to receive(:new).and_return(task_environment)
        end

        describe '#action' do
          let(:download_app_droplet_action) do
            ::Diego::Bbs::Models::DownloadAction.new(
              from: download_uri,
              to: '.',
              cache_key: '',
              user: 'vcap',
              checksum_algorithm: 'sha1',
              checksum_value: task.droplet.droplet_hash
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
        end

        describe '#task_environment_variables' do
          it 'returns task environment variables' do
            expect(builder.task_environment_variables).to match_array([
              ::Diego::Bbs::Models::EnvironmentVariable.new(name: 'VCAP_APPLICATION', value: '{"greg":"pants"}'),
              ::Diego::Bbs::Models::EnvironmentVariable.new(name: 'MEMORY_LIMIT', value: '256m'),
              ::Diego::Bbs::Models::EnvironmentVariable.new(name: 'VCAP_SERVICES', value: '{}')
            ])
            expect(VCAP::CloudController::Diego::TaskEnvironment).to have_received(:new).with(task.app, task, task.app.space, environment_json)
          end
        end

        describe '#stack' do
          it 'returns the stack' do
            expect(builder.stack).to eq('potato-stack')
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
