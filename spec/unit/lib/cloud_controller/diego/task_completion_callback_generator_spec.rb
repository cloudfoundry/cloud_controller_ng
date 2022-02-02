require 'spec_helper'
require 'cloud_controller/diego/task_completion_callback_generator'

module VCAP::CloudController
  module Diego
    RSpec.describe TaskCompletionCallbackGenerator do
      subject(:generator) { TaskCompletionCallbackGenerator.new(TestConfig.config_instance) }

      describe '#generate' do
        let(:task) { TaskModel.make }
        let(:kubernetes_config) { nil }
        let(:task_config) do
          {
            internal_service_hostname: 'google.com',
            internal_service_port:     '9090',
            tls_port:                  '8888',
            kubernetes:                kubernetes_config,
          }
        end

        before do
          TestConfig.override(task_config)
        end

        context 'when CC is responsible for syncing with Diego' do
          it 'returns a v4 completion callback url' do
            expect(generator.generate(task)).to eq(
              "https://google.com:8888/internal/v4/tasks/#{task.guid}/completed"
            )
          end
        end

        context 'when kubernetes is configured' do
          let(:kubernetes_config) do
            {
              host_url: 'https://main.default.svc.cluster-domain.example',
            }
          end

          it 'configures the callback url with http and relies on Istio for mTLS' do
            expect(generator.generate(task)).to eq(
              "http://google.com:9090/internal/v4/tasks/#{task.guid}/completed"
            )
          end
        end
      end
    end
  end
end
