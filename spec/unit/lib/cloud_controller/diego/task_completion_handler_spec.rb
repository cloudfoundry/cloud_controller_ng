require 'spec_helper'
require 'cloud_controller/diego/task_completion_handler'

module VCAP::CloudController
  module Diego
    RSpec.describe TaskCompletionHandler do
      let!(:task) { TaskModel.make }
      let(:handler) { TaskCompletionHandler.new }
      let(:logger) { instance_double(Steno::Logger, info: nil, error: nil, warn: nil) }

      before do
        allow(Steno).to receive(:logger).with('cc.tasks').and_return(logger)
      end

      describe '#complete_task' do
        context 'when the task succeeds' do
          let(:response) do
            {
              task_guid: task.guid,
              failed: false,
              failure_reason: '',
              result: '',
              created_at: 1
            }
          end

          it 'marks the task as succeeded' do
            handler.complete_task(task, response)
            expect(task.reload.state).to eq TaskModel::SUCCEEDED_STATE
            expect(task.reload.failure_reason).to eq(nil)
          end

          it 'creates an AppUsageEvent with state TASK_STOPPED' do
            expect {
              handler.complete_task(task, response)
            }.to change { AppUsageEvent.count }.by(1)

            event = AppUsageEvent.last
            expect(event.state).to eq('TASK_STOPPED')
            expect(event.task_guid).to eq(task.guid)
          end

          context 'when updating the task fails' do
            let(:save_error) { StandardError.new('save-error') }

            before do
              allow_any_instance_of(TaskModel).to receive(:save_changes).and_raise(save_error)
            end

            it 'logs an error' do
              handler.complete_task(task, response)
              expect(logger).to have_received(:error).with(
                'diego.tasks.saving-failed',
                task_guid: task.guid,
                payload: response,
                error: 'save-error',
              )
            end
          end
        end

        context 'when the task fails' do
          let(:response) do
            {
              task_guid: task.guid,
              failed: true,
              failure_reason: 'ruh roh',
              result: '',
              created_at: 1
            }
          end

          it 'marks the task as failed and sets the result message' do
            handler.complete_task(task, response)
            expect(task.reload.state).to eq TaskModel::FAILED_STATE
            expect(task.reload.failure_reason).to eq 'ruh roh'
          end

          context 'when updating the task fails' do
            let(:save_error) { StandardError.new('save-error') }

            before do
              allow_any_instance_of(TaskModel).to receive(:save_changes).and_raise(save_error)
            end

            it 'logs an error' do
              handler.complete_task(task, response)
              expect(logger).to have_received(:error).with(
                'diego.tasks.saving-failed',
                task_guid: task.guid,
                payload: response,
                error: 'save-error',
              )
            end
          end
        end

        context 'validations' do
          context 'when the failed field is missing' do
            let(:response) do
              {
                failure_reason: '',
              }
            end

            it 'fails the task' do
              handler.complete_task(task, response)
              expect(task.reload.state).to eq(TaskModel::FAILED_STATE)
              expect(task.reload.failure_reason).to eq 'Malformed task response from Diego'
            end
          end

          context 'when the failure reason field is missing' do
            let(:response) do
              {
                failed: true,
              }
            end

            it 'fails the task' do
              handler.complete_task(task, response)
              expect(task.reload.state).to eq(TaskModel::FAILED_STATE)
              expect(task.reload.failure_reason).to eq 'Malformed task response from Diego'
            end
          end
        end
      end
    end
  end
end
