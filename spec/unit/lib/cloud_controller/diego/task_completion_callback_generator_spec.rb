require 'spec_helper'
require 'cloud_controller/diego/task_completion_callback_generator'

module VCAP::CloudController
  module Diego
    RSpec.describe TaskCompletionCallbackGenerator do
      subject(:generator) { described_class.new(TestConfig.config) }

      describe '#generate' do
        let(:task) { TaskModel.make }
        let(:task_config) do
          {
            internal_api: {
              auth_user: 'utako',
              auth_password: 'luan'
            },
            internal_service_hostname: 'google.com',
            external_port: '1234'
          }
        end

        before do
          TestConfig.override(task_config)
        end

        it 'returns a completion callback url' do
          url = generator.generate(task)

          expect(url).to eq "http://utako:luan@google.com:1234/internal/v3/tasks/#{task.guid}/completed"
        end
      end
    end
  end
end
