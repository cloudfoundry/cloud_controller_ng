require 'spec_helper'

module VCAP::CloudController
  module Jobs::Runtime
    RSpec.describe ServiceOperationsUpdateInProgressCleanup, job_context: :worker do
      subject(:job) { ServiceOperationsUpdateInProgressCleanup.new }

      let(:fake_logger) { instance_double(Steno::Logger, info: nil, warn: nil) }
      let(:max_poll_duration_minutes) { 60 }

      before do
        allow(Steno).to receive(:logger).and_return(fake_logger)
        TestConfig.override(broker_client_max_async_poll_duration_minutes: max_poll_duration_minutes)
      end

      def prepare_stuck_service_instance(
        service_instance_state: 'in progress',
        service_instance_type: 'update',
        service_instance_created_at: Time.now,
        pollable_job_state: PollableJobModel::FAILED_STATE,
        pollable_job_operation: 'service_instance.update',
        delayed_job_failed_at: Time.now
      )
        service_instance = create(:managed_service_instance)

        create(:service_instance_operation,
               service_instance_id: service_instance.id,
               type: service_instance_type,
               state: service_instance_state,
               created_at: service_instance_created_at)

        dj = Delayed::Job.create!(
          guid: SecureRandom.uuid,
          handler: 'fake',
          run_at: Time.now,
          failed_at: delayed_job_failed_at,
          queue: 'cc-generic'
        )

        pjob = create(:pollable_job_model,
                      state: pollable_job_state,
                      operation: pollable_job_operation,
                      resource_guid: service_instance.guid,
                      resource_type: 'service_instances',
                      delayed_job_guid: dj.guid)

        { service_instance: service_instance, pjob: pjob, delayed_job: dj }
      end

      shared_examples 'does not resolve the operation' do
        it 'leaves the operation in progress and the pollable job untouched' do
          scenario = subject_scenario
          job.perform
          expect(scenario[:service_instance].last_operation.reload.state).to eq('in progress')
          expect(scenario[:pjob].reload.state).to eq(scenario[:pjob].state)
        end
      end

      it { is_expected.to be_a_valid_job }

      describe '#perform' do
        context 'when sio state is not in progress' do
          it 'does not resolve when state is succeeded' do
            scenario = prepare_stuck_service_instance(service_instance_state: 'succeeded')
            job.perform
            expect(scenario[:service_instance].last_operation.reload.state).to eq('succeeded')
          end

          it 'does not resolve when state is failed' do
            scenario = prepare_stuck_service_instance(service_instance_state: 'failed')
            job.perform
            expect(scenario[:service_instance].last_operation.reload.state).to eq('failed')
          end
        end

        context 'when sio type is not update' do
          let(:subject_scenario) { prepare_stuck_service_instance(service_instance_type: 'create') }

          it_behaves_like 'does not resolve the operation'
        end

        context 'when sio created_at is beyond the max polling window' do
          let(:subject_scenario) { prepare_stuck_service_instance(service_instance_created_at: Time.now - (max_poll_duration_minutes + 1).minutes) }

          it_behaves_like 'does not resolve the operation'
        end

        context 'when delayed_job.failed_at is nil (job still running or locked)' do
          let(:subject_scenario) { prepare_stuck_service_instance(delayed_job_failed_at: nil) }

          it_behaves_like 'does not resolve the operation'
        end

        context 'when pollable job state is COMPLETE' do
          let(:subject_scenario) { prepare_stuck_service_instance(pollable_job_state: PollableJobModel::COMPLETE_STATE) }

          it_behaves_like 'does not resolve the operation'
        end

        context 'when pollable job state is PROCESSING' do
          let(:subject_scenario) { prepare_stuck_service_instance(pollable_job_state: PollableJobModel::PROCESSING_STATE) }

          it_behaves_like 'does not resolve the operation'
        end

        context 'when pollable job operation is not service_instance.update' do
          let(:subject_scenario) { prepare_stuck_service_instance(pollable_job_operation: 'service_instance.create') }

          it_behaves_like 'does not resolve the operation'
        end

        context 'when a service instance update job is stuck with state FAILED' do
          it 'sets operation to failed and pollable job to FAILED' do
            scenario = prepare_stuck_service_instance
            job.perform
            expect(scenario[:service_instance].last_operation.reload.state).to eq('failed')
            expect(scenario[:pjob].reload.state).to eq(PollableJobModel::FAILED_STATE)
          end
        end

        context 'when a service instance update job is stuck with state POLLING (DB flip before failure hook)' do
          it 'sets operation to failed and pollable job to FAILED' do
            scenario = prepare_stuck_service_instance(pollable_job_state: PollableJobModel::POLLING_STATE)
            job.perform
            expect(scenario[:service_instance].last_operation.reload.state).to eq('failed')
            expect(scenario[:pjob].reload.state).to eq(PollableJobModel::FAILED_STATE)
          end
        end

        context 'when there are multiple stuck jobs within the batch size' do
          it 'resolves each one' do
            3.times { prepare_stuck_service_instance }
            job.perform
            expect(ServiceInstanceOperation.where(state: 'failed').count).to eq(3)
          end
        end

        context 'when there are more stuck jobs than the batch size' do
          it 'processes only up to BATCH_SIZE jobs per run' do
            (ServiceOperationsUpdateInProgressCleanup::BATCH_SIZE + 1).times { prepare_stuck_service_instance }
            job.perform
            expect(ServiceInstanceOperation.where(state: 'failed').count).to eq(ServiceOperationsUpdateInProgressCleanup::BATCH_SIZE)
          end
        end
      end

      describe '#resolve_stuck' do
        context 'when another process already resolved it (skip_locked returns nil)' do
          it 'does nothing' do
            scenario = prepare_stuck_service_instance

            expect do
              job.send(:resolve_stuck, ServiceInstanceOperation, ServiceInstance,
                       -1, scenario[:service_instance].id, scenario[:pjob].guid)
            end.not_to raise_error
            expect(scenario[:service_instance].last_operation.reload.state).to eq('in progress')
          end
        end

        context 'when the operation is stuck in progress' do
          it 'sets the operation state from in progress to failed' do
            scenario = prepare_stuck_service_instance
            op = scenario[:service_instance].last_operation

            expect do
              job.send(:resolve_stuck, ServiceInstanceOperation, ServiceInstance,
                       op.id, scenario[:service_instance].id, scenario[:pjob].guid)
            end.to change { op.reload.state }.from('in progress').to('failed')
          end

          it 'sets the pollable job state to FAILED' do
            scenario = prepare_stuck_service_instance(pollable_job_state: PollableJobModel::POLLING_STATE)
            op = scenario[:service_instance].last_operation

            expect do
              job.send(:resolve_stuck, ServiceInstanceOperation, ServiceInstance,
                       op.id, scenario[:service_instance].id, scenario[:pjob].guid)
            end.to change { scenario[:pjob].reload.state }.from(PollableJobModel::POLLING_STATE).to(PollableJobModel::FAILED_STATE)
          end
        end
      end
    end
  end
end
