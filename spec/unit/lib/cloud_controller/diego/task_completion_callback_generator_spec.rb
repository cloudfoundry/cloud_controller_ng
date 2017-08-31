require 'spec_helper'
require 'cloud_controller/diego/task_completion_callback_generator'

module VCAP::CloudController
  module Diego
    RSpec.describe TaskCompletionCallbackGenerator do
      subject(:generator) { TaskCompletionCallbackGenerator.new(TestConfig.config_instance) }

      describe '#generate' do
        let(:task) { TaskModel.make }
        let(:task_config) do
          {
            internal_service_hostname: 'google.com',
            tls_port:                  '8888',
            external_port:             '8881',
            diego:                     {
              temporary_local_tps: true,
              temporary_local_sync: temporary_local_sync
            },
            internal_api: {
              auth_user: 'username',
              auth_password: 'password'
            }
          }
        end

        before do
          TestConfig.override(task_config)
        end

        context 'when CC is responsible for syncing with Diego' do
          let(:temporary_local_sync) { true }

          it 'returns a v4 completion callback url' do
            expect(generator.generate(task)).to eq(
              "https://google.com:8888/internal/v4/tasks/#{task.guid}/completed"
            )
          end
        end

        context 'when the bridge is still handling syncing CC and Diego' do
          let(:temporary_local_sync) { false }

          it 'returns a v3 completion callback url' do
            expect(generator.generate(task)).to eq(
              "http://username:password@google.com:8881/internal/v3/tasks/#{task.guid}/completed"
            )
          end
        end

        context 'when there is no "diego" configuration (this is only possible in tests)' do
          let(:task_config) do
            {
              internal_service_hostname: 'google.com',
              tls_port:                  '8888',
              external_port:             '8881',
              internal_api: {
                auth_user: 'username',
                auth_password: 'password'
              }
            }
          end

          it 'returns a v3 completion callback url' do
            expect(generator.generate(task)).to eq(
              "http://username:password@google.com:8881/internal/v3/tasks/#{task.guid}/completed"
            )
          end
        end

        context 'when there is no "internal_api" configuration and local sync is on (this is only possible in tests)' do
          let(:task_config) do
            {
              internal_service_hostname: 'google.com',
              tls_port:                  '8888',
              external_port: '8881',
              diego:                     {
                temporary_local_tps: true,
                temporary_local_sync: true
              },
            }
          end

          it 'returns a v4 completion callback url' do
            expect(generator.generate(task)).to eq(
              "https://google.com:8888/internal/v4/tasks/#{task.guid}/completed"
            )
          end
        end
      end
    end
  end
end
