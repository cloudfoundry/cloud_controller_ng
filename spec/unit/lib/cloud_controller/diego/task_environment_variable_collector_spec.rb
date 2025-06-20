require 'spec_helper'
require 'cloud_controller/diego/task_environment_variable_collector'

module VCAP::CloudController
  module Diego
    RSpec.describe TaskEnvironmentVariableCollector do
      let(:task) { TaskModel.make command: command, name: 'my-task' }
      let(:command) { 'echo "hello"' }
      let(:environment_json) { { 'RIZ' => 'shirt' } }

      before do
        VCAP::CloudController::EnvironmentVariableGroup.running.update(environment_json:)
        task_environment = instance_double(VCAP::CloudController::Diego::TaskEnvironment)
        allow(task_environment).to receive(:build).and_return(
          { 'VCAP_APPLICATION' => { greg: 'pants' }, 'MEMORY_LIMIT' => '256m', 'VCAP_SERVICES' => {}, 'VCAP_PLATFORM_OPTIONS' => { credhuburi: 'credhub.place:port' } }
        )
        allow(VCAP::CloudController::Diego::TaskEnvironment).to receive(:new).and_return(task_environment)
      end

      describe '.for_task' do
        it 'returns task environment variables' do
          task_collector = TaskEnvironmentVariableCollector.for_task(task)
          expected = [
            ::Diego::Bbs::Models::EnvironmentVariable.new(name: 'VCAP_APPLICATION', value: '{"greg":"pants"}'),
            ::Diego::Bbs::Models::EnvironmentVariable.new(name: 'MEMORY_LIMIT', value: '256m'),
            ::Diego::Bbs::Models::EnvironmentVariable.new(name: 'VCAP_SERVICES', value: '{}'),
            ::Diego::Bbs::Models::EnvironmentVariable.new(name: 'VCAP_PLATFORM_OPTIONS', value: '{"credhuburi":"credhub.place:port"}')
          ]
          expect(task_collector).to match_array(expected)
          expect(VCAP::CloudController::Diego::TaskEnvironment).to have_received(:new).with(task.app, task, task.app.space, environment_json)
        end

        context 'when the parent app has windows credential refs' do
          before do
            allow(WindowsEnvironmentSage).to receive(:ponder).and_return([::Diego::Bbs::Models::EnvironmentVariable.new(name: 'WINDOWS_GMSA_CREDENTIAL_REF',
                                                                                                                        value: '/credhub/ref')])
          end

          it 'includes the WINDOWS_GMSA_CREDENTIAL_REF env var' do
            task_collector = TaskEnvironmentVariableCollector.for_task(task)
            expected = [
              ::Diego::Bbs::Models::EnvironmentVariable.new(name: 'VCAP_APPLICATION', value: '{"greg":"pants"}'),
              ::Diego::Bbs::Models::EnvironmentVariable.new(name: 'MEMORY_LIMIT', value: '256m'),
              ::Diego::Bbs::Models::EnvironmentVariable.new(name: 'VCAP_SERVICES', value: '{}'),
              ::Diego::Bbs::Models::EnvironmentVariable.new(name: 'VCAP_PLATFORM_OPTIONS', value: '{"credhuburi":"credhub.place:port"}'),
              ::Diego::Bbs::Models::EnvironmentVariable.new(name: 'WINDOWS_GMSA_CREDENTIAL_REF', value: '/credhub/ref')
            ]
            expect(task_collector).to match_array(expected)
          end
        end
      end
    end
  end
end
