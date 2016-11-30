require 'spec_helper'

module VCAP::CloudController
  module Diego
    RSpec.describe TaskEnvironmentVariableCollector do
      let(:task) { TaskModel.make command: command, name: 'my-task' }
      let(:command) { 'echo "hello"' }
      let(:environment_json) { { RIZ: 'shirt' }.to_json }

      before do
        VCAP::CloudController::EnvironmentVariableGroup.running.update(environment_json: environment_json)
        task_environment = instance_double(VCAP::CloudController::Diego::TaskEnvironment)
        allow(task_environment).to receive(:build).and_return(
          { 'VCAP_APPLICATION' => { greg: 'pants' }, 'MEMORY_LIMIT' => '256m', 'VCAP_SERVICES' => {} }
        )
        allow(VCAP::CloudController::Diego::TaskEnvironment).to receive(:new).and_return(task_environment)
      end

      describe '.for_task' do
        it 'returns task environment variables' do
          expect(TaskEnvironmentVariableCollector.for_task(task)).to match_array([
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
