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
            internal_service_hostname: 'google.com',
            tls_port: '8888',
            diego: {
              temporary_local_tps: true,
            }
          }
        end

        before do
          TestConfig.override(task_config)
        end

        it 'returns a completion callback url' do
          expect(generator.generate(task)).to eq(
            "https://google.com:8888/internal/v4/tasks/#{task.guid}/completed"
          )
        end
      end
    end
  end
end
