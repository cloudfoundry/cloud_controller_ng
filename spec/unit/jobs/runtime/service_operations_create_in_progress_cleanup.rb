require 'spec_helper'

module VCAP::CloudController
  module Jobs::Runtime
    RSpec.describe ServiceOperationsCreateInProgressCleanup, job_context: :worker do
      subject(:job) { ServiceOperationsCreateInProgressCleanup.new }

      let(:fake_logger) { instance_double(Steno::Logger, info: nil, warn: nil) }
      let(:fake_mitigator) { instance_double(VCAP::Services::ServiceBrokers::V2::OrphanMitigator) }
      let(:max_poll_duration_minutes) { 60 }

      before do
        allow(Steno).to receive(:logger).and_return(fake_logger)
        TestConfig.override(broker_client_max_async_poll_duration_minutes: max_poll_duration_minutes)
        allow(VCAP::Services::ServiceBrokers::V2::OrphanMitigator).to receive(:new).and_return(fake_mitigator)
        allow(fake_mitigator).to receive(:cleanup_failed_provision)
        allow(fake_mitigator).to receive(:cleanup_failed_bind)
        allow(fake_mitigator).to receive(:cleanup_failed_key)
      end

      # Builds a fully stuck scenario for ServiceInstance create that the job should pick up and mitigate.
      # All filter conditions are satisfied: sio is in progress/create/within cutoff,
      # pjob is FAILED with operation=service_instance.create, delayed_job has failed_at set.
      # Override individual parameters to break a single filter and test exclusion.
      def make_stuck_scenario(
        sio_state: 'in progress',
        sio_type: 'create',
        sio_created_at: Time.now,
        pjob_state: PollableJobModel::FAILED_STATE,
        dj_failed_at: Time.now
      )
        service_instance = ManagedServiceInstance.make

        ServiceInstanceOperation.make(
          service_instance_id: service_instance.id,
          type: sio_type,
          state: sio_state,
          created_at: sio_created_at
        )

        dj = Delayed::Job.create!(
          guid: SecureRandom.uuid,
          handler: 'fake',
          run_at: Time.now,
          failed_at: dj_failed_at,
          queue: 'cc-generic'
        )

        pjob = PollableJobModel.make(
          state: pjob_state,
          operation: 'service_instance.create',
          resource_guid: service_instance.guid,
          resource_type: 'service_instances',
          delayed_job_guid: dj.guid
        )

        { service_instance: service_instance, pjob: pjob, delayed_job: dj }
      end

      it { is_expected.to be_a_valid_job }

      describe '#perform' do
        context 'when sio state is not in progress' do
          it 'does not mitigate when state is succeeded' do
            scenario = make_stuck_scenario(sio_state: 'succeeded')
            job.perform
            expect(scenario[:service_instance].last_operation.reload.state).to eq('succeeded')
            expect(fake_mitigator).not_to have_received(:cleanup_failed_provision)
          end

          it 'does not mitigate when state is failed' do
            scenario = make_stuck_scenario(sio_state: 'failed')
            job.perform
            expect(scenario[:service_instance].last_operation.reload.state).to eq('failed')
            expect(fake_mitigator).not_to have_received(:cleanup_failed_provision)
          end
        end

        context 'when sio type is not create' do
          it 'does not mitigate' do
            scenario = make_stuck_scenario(sio_type: 'delete')
            job.perform
            expect(scenario[:service_instance].last_operation.reload.state).to eq('in progress')
            expect(fake_mitigator).not_to have_received(:cleanup_failed_provision)
          end
        end

        context 'when sio created_at is beyond the max polling window' do
          it 'does not mitigate' do
            scenario = make_stuck_scenario(sio_created_at: Time.now - (max_poll_duration_minutes + 1).minutes)
            job.perform
            expect(scenario[:service_instance].last_operation.reload.state).to eq('in progress')
            expect(fake_mitigator).not_to have_received(:cleanup_failed_provision)
          end
        end

        context 'when delayed_job.failed_at is nil (job still running or locked)' do
          it 'does not mitigate' do
            scenario = make_stuck_scenario(dj_failed_at: nil)
            job.perform
            expect(scenario[:service_instance].last_operation.reload.state).to eq('in progress')
            expect(fake_mitigator).not_to have_received(:cleanup_failed_provision)
          end
        end

        context 'when pollable job state is COMPLETE' do
          it 'does not mitigate' do
            scenario = make_stuck_scenario(pjob_state: PollableJobModel::COMPLETE_STATE)
            job.perform
            expect(scenario[:service_instance].last_operation.reload.state).to eq('in progress')
            expect(fake_mitigator).not_to have_received(:cleanup_failed_provision)
          end
        end

        context 'when pollable job state is PROCESSING' do
          it 'does not mitigate' do
            scenario = make_stuck_scenario(pjob_state: PollableJobModel::PROCESSING_STATE)
            job.perform
            expect(scenario[:service_instance].last_operation.reload.state).to eq('in progress')
            expect(fake_mitigator).not_to have_received(:cleanup_failed_provision)
          end
        end

        context 'when pollable job operation is not service_instance.create' do
          it 'does not mitigate' do
            scenario = make_stuck_scenario
            scenario[:pjob].update(operation: 'service_instance.update')
            job.perform
            expect(scenario[:service_instance].last_operation.reload.state).to eq('in progress')
            expect(fake_mitigator).not_to have_received(:cleanup_failed_provision)
          end
        end

        context 'when a service instance create job is stuck with state FAILED' do
          it 'sets operation to failed, pollable job to FAILED, and triggers orphan mitigation' do
            scenario = make_stuck_scenario
            job.perform
            expect(scenario[:service_instance].last_operation.reload.state).to eq('failed')
            expect(scenario[:pjob].reload.state).to eq(PollableJobModel::FAILED_STATE)
            expect(fake_mitigator).to have_received(:cleanup_failed_provision).with(scenario[:service_instance])
          end
        end

        context 'when a service instance create job is stuck with state POLLING (DB flip before failure hook)' do
          it 'sets operation to failed, pollable job to FAILED, and triggers orphan mitigation' do
            scenario = make_stuck_scenario(pjob_state: PollableJobModel::POLLING_STATE)
            job.perform
            expect(scenario[:service_instance].last_operation.reload.state).to eq('failed')
            expect(scenario[:pjob].reload.state).to eq(PollableJobModel::FAILED_STATE)
            expect(fake_mitigator).to have_received(:cleanup_failed_provision).with(scenario[:service_instance])
          end
        end

        context 'when there are multiple stuck jobs within the batch size' do
          it 'mitigates each one' do
            3.times { make_stuck_scenario }
            job.perform
            expect(ServiceInstanceOperation.where(state: 'failed').count).to eq(3)
          end
        end

        context 'when there are more stuck jobs than the batch size' do
          it 'processes only up to BATCH_SIZE jobs per run' do
            (ServiceOperationsCreateInProgressCleanup::BATCH_SIZE + 1).times { make_stuck_scenario }
            job.perform
            expect(ServiceInstanceOperation.where(state: 'failed').count).to eq(ServiceOperationsCreateInProgressCleanup::BATCH_SIZE)
          end
        end

        context 'when a service binding create job is stuck' do
          it 'sets operation to failed, pollable job to FAILED, and triggers orphan mitigation' do
            service_binding = ServiceBinding.make
            ServiceBindingOperation.make(
              service_binding_id: service_binding.id,
              type: 'create',
              state: 'in progress'
            )
            dj = Delayed::Job.create!(guid: SecureRandom.uuid, handler: 'fake', run_at: Time.now, failed_at: Time.now, queue: 'cc-generic')
            pjob = PollableJobModel.make(
              state: PollableJobModel::FAILED_STATE,
              operation: 'service_bindings.create',
              resource_guid: service_binding.guid,
              resource_type: 'service_bindings',
              delayed_job_guid: dj.guid
            )

            job.perform

            expect(service_binding.last_operation.reload.state).to eq('failed')
            expect(pjob.reload.state).to eq(PollableJobModel::FAILED_STATE)
            expect(fake_mitigator).to have_received(:cleanup_failed_bind).with(service_binding)
          end
        end

        context 'when a service key create job is stuck' do
          it 'sets operation to failed, pollable job to FAILED, and triggers orphan mitigation' do
            service_key = ServiceKey.make
            ServiceKeyOperation.make(
              service_key_id: service_key.id,
              type: 'create',
              state: 'in progress'
            )
            dj = Delayed::Job.create!(guid: SecureRandom.uuid, handler: 'fake', run_at: Time.now, failed_at: Time.now, queue: 'cc-generic')
            pjob = PollableJobModel.make(
              state: PollableJobModel::FAILED_STATE,
              operation: 'service_keys.create',
              resource_guid: service_key.guid,
              resource_type: 'service_keys',
              delayed_job_guid: dj.guid
            )

            job.perform

            expect(service_key.last_operation.reload.state).to eq('failed')
            expect(pjob.reload.state).to eq(PollableJobModel::FAILED_STATE)
            expect(fake_mitigator).to have_received(:cleanup_failed_key).with(service_key)
          end
        end
      end

      describe '#mitigate_orphan' do
        context 'when another process already mitigated (skip_locked returns nil)' do
          it 'does nothing' do
            scenario = make_stuck_scenario

            expect do
              job.send(:mitigate_orphan, ServiceInstanceOperation, ServiceInstance,
                       :cleanup_failed_provision, -1, scenario[:service_instance].id, scenario[:pjob].guid)
            end.not_to raise_error
            expect(fake_mitigator).not_to have_received(:cleanup_failed_provision)
          end
        end

        context 'when the operation is stuck in progress' do
          it 'sets the operation state from in progress to failed' do
            scenario = make_stuck_scenario
            op = scenario[:service_instance].last_operation

            expect do
              job.send(:mitigate_orphan, ServiceInstanceOperation, ServiceInstance,
                       :cleanup_failed_provision, op.id, scenario[:service_instance].id, scenario[:pjob].guid)
            end.to change { op.reload.state }.from('in progress').to('failed')
          end

          it 'sets the pollable job state to FAILED' do
            scenario = make_stuck_scenario(pjob_state: PollableJobModel::POLLING_STATE)
            op = scenario[:service_instance].last_operation

            expect do
              job.send(:mitigate_orphan, ServiceInstanceOperation, ServiceInstance,
                       :cleanup_failed_provision, op.id, scenario[:service_instance].id, scenario[:pjob].guid)
            end.to change { scenario[:pjob].reload.state }.from(PollableJobModel::POLLING_STATE).to(PollableJobModel::FAILED_STATE)
          end
        end
      end
    end
  end
end
