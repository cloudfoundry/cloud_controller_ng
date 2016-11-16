require 'spec_helper'
require 'cloud_controller/diego/buildpack/task_action_builder'

module VCAP::CloudController
  module Diego
    module Buildpack
      RSpec.describe TaskActionBuilder do
        subject(:builder) { described_class.new task }

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

        before do
          VCAP::CloudController::EnvironmentVariableGroup.running.update(environment_json: environment_json)
          task_environment = instance_double(VCAP::CloudController::Diego::TaskEnvironment)
          allow(task_environment).to receive(:build).and_return(
            { 'VCAP_APPLICATION' => { greg: 'pants' }, 'MEMORY_LIMIT' => '256m', 'VCAP_SERVICES' => {} }
          )
          allow(VCAP::CloudController::Diego::TaskEnvironment).to receive(:new).and_return(task_environment)
        end

        describe '#action' do
          let(:download_uri) { 'http://download_droplet.example.com' }
          let(:lifecycle_data) { { droplet_download_uri: download_uri } }

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
            result = builder.action(lifecycle_data)

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
      end
    end
  end
end
