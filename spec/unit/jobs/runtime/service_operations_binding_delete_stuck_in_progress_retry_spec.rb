require 'spec_helper'

module VCAP::CloudController
  module Jobs::Runtime
    RSpec.describe ServiceOperationsBindingDeleteStuckInProgressRetry, job_context: :worker do
      subject(:job) { ServiceOperationsBindingDeleteStuckInProgressRetry.new }

      let(:fake_logger) { instance_double(Steno::Logger, info: nil, warn: nil, error: nil) }
      let(:max_poll_duration_minutes) { 60 }
      let(:user_audit_info) { UserAuditInfo.new(user_guid: create(:user).guid, user_email: 'foo@example.com') }
      let(:enqueuer) { instance_double(Jobs::GenericEnqueuer, enqueue_pollable: nil) }

      before do
        allow(Steno).to receive(:logger).and_return(fake_logger)
        TestConfig.override(broker_client_max_async_poll_duration_minutes: max_poll_duration_minutes)
        allow(Jobs::GenericEnqueuer).to receive(:shared).and_return(enqueuer)
      end

      # Enqueue a real DeleteBindingJob so the delayed_job carries a genuine serialized handler,
      # then simulate the permanent failure (failed_at set) that leaves the operation stuck in progress.
      def prepare_stuck_binding(
        binding_type:,
        operation_state: 'in progress',
        operation_type: 'delete',
        operation_created_at: Time.now,
        pollable_job_state: PollableJobModel::FAILED_STATE,
        pollable_job_operation: nil,
        delayed_job_failed_at: Time.now
      )
        if binding_type == :credential
          binding = create(:service_binding)
          create(:service_binding_operation, service_binding_id: binding.id, type: operation_type, state: operation_state, created_at: operation_created_at)
          default_operation = 'service_bindings.delete'
          resource_type = 'service_bindings'
        else
          binding = create(:service_key)
          create(:service_key_operation, service_key_id: binding.id, type: operation_type, state: operation_state, created_at: operation_created_at)
          default_operation = 'service_keys.delete'
          resource_type = 'service_keys'
        end

        delete_job = V3::DeleteBindingJob.new(binding_type, binding.guid, user_audit_info: user_audit_info)
        pjob = Jobs::Enqueuer.new(queue: Jobs::Queues.generic).enqueue_pollable(delete_job)
        pjob.update(state: pollable_job_state, operation: pollable_job_operation || default_operation, resource_type: resource_type)

        dj = Delayed::Job[guid: pjob.delayed_job_guid]
        dj.update(failed_at: delayed_job_failed_at)

        { binding: binding, pjob: pjob, delayed_job: dj }
      end

      it { is_expected.to be_a_valid_job }

      %i[credential key].each do |binding_type|
        describe "#perform for #{binding_type} bindings" do
          shared_examples 'does not retry the operation' do
            it 'leaves the operation in progress, the pollable job untouched, and does not re-enqueue' do
              scenario = subject_scenario
              original_pollable_state = scenario[:pjob].state
              job.perform
              expect(scenario[:binding].last_operation.reload.state).to eq('in progress')
              expect(scenario[:pjob].reload.state).to eq(original_pollable_state)
              expect(enqueuer).not_to have_received(:enqueue_pollable)
            end
          end

          context 'when operation state is not in progress' do
            it 'does not retry when state is succeeded' do
              scenario = prepare_stuck_binding(binding_type: binding_type, operation_state: 'succeeded')
              job.perform
              expect(scenario[:binding].last_operation.reload.state).to eq('succeeded')
              expect(enqueuer).not_to have_received(:enqueue_pollable)
            end

            it 'does not retry when state is failed' do
              scenario = prepare_stuck_binding(binding_type: binding_type, operation_state: 'failed')
              job.perform
              expect(scenario[:binding].last_operation.reload.state).to eq('failed')
              expect(enqueuer).not_to have_received(:enqueue_pollable)
            end
          end

          context 'when operation type is not delete' do
            let(:subject_scenario) do
              prepare_stuck_binding(binding_type: binding_type, operation_type: 'create',
                                    pollable_job_operation: binding_type == :credential ? 'service_bindings.create' : 'service_keys.create')
            end

            it_behaves_like 'does not retry the operation'
          end

          context 'when operation created_at is beyond the max polling window' do
            let(:subject_scenario) { prepare_stuck_binding(binding_type: binding_type, operation_created_at: Time.now - (max_poll_duration_minutes + 1).minutes) }

            it_behaves_like 'does not retry the operation'
          end

          context 'when delayed_job.failed_at is nil (job still running or locked)' do
            let(:subject_scenario) { prepare_stuck_binding(binding_type: binding_type, delayed_job_failed_at: nil) }

            it_behaves_like 'does not retry the operation'
          end

          context 'when pollable job state is COMPLETE' do
            let(:subject_scenario) { prepare_stuck_binding(binding_type: binding_type, pollable_job_state: PollableJobModel::COMPLETE_STATE) }

            it_behaves_like 'does not retry the operation'
          end

          context 'when pollable job state is PROCESSING' do
            let(:subject_scenario) { prepare_stuck_binding(binding_type: binding_type, pollable_job_state: PollableJobModel::PROCESSING_STATE) }

            it_behaves_like 'does not retry the operation'
          end

          context 'when pollable job operation does not match the delete operation' do
            let(:subject_scenario) do
              prepare_stuck_binding(binding_type: binding_type,
                                    pollable_job_operation: binding_type == :credential ? 'service_bindings.create' : 'service_keys.create')
            end

            it_behaves_like 'does not retry the operation'
          end

          context 'when a binding delete job is stuck with state FAILED' do
            it 'resets the pollable job to POLLING and re-enqueues the original delete job' do
              scenario = prepare_stuck_binding(binding_type: binding_type)
              job.perform

              expect(scenario[:binding].last_operation.reload.state).to eq('in progress')
              expect(scenario[:pjob].reload.state).to eq(PollableJobModel::POLLING_STATE)
              expect(enqueuer).to have_received(:enqueue_pollable).with(
                an_instance_of(V3::DeleteBindingJob),
                hash_including(existing_guid: scenario[:pjob].guid, preserve_priority: true)
              )
            end
          end

          context 'when a binding delete job is stuck with state POLLING (DB flip before failure hook)' do
            it 'resets the pollable job to POLLING and re-enqueues the original delete job' do
              scenario = prepare_stuck_binding(binding_type: binding_type, pollable_job_state: PollableJobModel::POLLING_STATE)
              job.perform

              expect(scenario[:pjob].reload.state).to eq(PollableJobModel::POLLING_STATE)
              expect(enqueuer).to have_received(:enqueue_pollable).with(
                an_instance_of(V3::DeleteBindingJob),
                hash_including(existing_guid: scenario[:pjob].guid)
              )
            end
          end

          context 'when there are multiple stuck jobs within the batch size' do
            it 'retries each one' do
              3.times { prepare_stuck_binding(binding_type: binding_type) }
              job.perform
              expect(enqueuer).to have_received(:enqueue_pollable).exactly(3).times
            end
          end

          context 'when there are more stuck jobs than the batch size' do
            it 'processes only up to BATCH_SIZE jobs per run' do
              (ServiceOperationsBindingDeleteStuckInProgressRetry::BATCH_SIZE + 1).times { prepare_stuck_binding(binding_type: binding_type) }
              job.perform
              expect(enqueuer).to have_received(:enqueue_pollable).exactly(ServiceOperationsBindingDeleteStuckInProgressRetry::BATCH_SIZE).times
            end
          end
        end
      end

      describe '#perform cross-type isolation' do
        it 'retries both a stuck credential-binding delete and a stuck key delete' do
          prepare_stuck_binding(binding_type: :credential)
          prepare_stuck_binding(binding_type: :key)
          job.perform
          expect(enqueuer).to have_received(:enqueue_pollable).exactly(2).times
        end
      end

      describe '#resolve_stuck' do
        context 'when another process already resolved it (skip_locked returns nil)' do
          it 'does nothing and does not re-enqueue' do
            scenario = prepare_stuck_binding(binding_type: :credential)

            expect do
              job.send(:resolve_stuck, ServiceBindingOperation, ServiceBinding,
                       -1, scenario[:binding].id, scenario[:pjob].guid)
            end.not_to raise_error
            expect(scenario[:pjob].reload.state).to eq(PollableJobModel::FAILED_STATE)
            expect(enqueuer).not_to have_received(:enqueue_pollable)
          end
        end

        context 'when the delayed job handler cannot be deserialized' do
          it 'does not re-enqueue and leaves the pollable job untouched' do
            scenario = prepare_stuck_binding(binding_type: :credential)
            Delayed::Job[guid: scenario[:pjob].delayed_job_guid].update(handler: 'not-valid-yaml: ]')
            op = scenario[:binding].last_operation

            job.send(:resolve_stuck, ServiceBindingOperation, ServiceBinding,
                     op.id, scenario[:binding].id, scenario[:pjob].guid)

            expect(scenario[:pjob].reload.state).to eq(PollableJobModel::FAILED_STATE)
            expect(enqueuer).not_to have_received(:enqueue_pollable)
          end
        end

        context 'when the operation is stuck in progress' do
          it 'resets the pollable job from its failed state to POLLING' do
            scenario = prepare_stuck_binding(binding_type: :credential)
            op = scenario[:binding].last_operation

            expect do
              job.send(:resolve_stuck, ServiceBindingOperation, ServiceBinding,
                       op.id, scenario[:binding].id, scenario[:pjob].guid)
            end.to change { scenario[:pjob].reload.state }.from(PollableJobModel::FAILED_STATE).to(PollableJobModel::POLLING_STATE)
          end
        end
      end
    end
  end
end
