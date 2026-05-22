require 'spec_helper'

module VCAP::CloudController
  module Jobs::Runtime
    RSpec.describe DelayedJobsRecover, job_context: :worker do
      subject(:job) { DelayedJobsRecover.new }

      let(:fake_logger) { instance_double(Steno::Logger, info: nil, warn: nil) }
      let(:max_poll_duration_minutes) { 60 }

      before do
        allow(Steno).to receive(:logger).and_return(fake_logger)
        TestConfig.override(broker_client_max_async_poll_duration_minutes: max_poll_duration_minutes)
      end

      # Builds a fully stuck scenario that the job should pick up and re-enqueue by default.
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
        context 'when there are no stuck jobs' do
          it 'does nothing' do
            make_stuck_scenario(sio_state: 'succeeded')
            expect(fake_logger).to receive(:info).with('Recover halted delayed jobs')
            expect { job.perform }.not_to(change { PollableJobModel.where(state: PollableJobModel::POLLING_STATE).count })
          end
        end

        context 'when sio state is not in progress' do
          it 'does not re-enqueue' do
            scenario = make_stuck_scenario(sio_state: 'succeeded')
            job.perform
            expect(scenario[:pjob].reload.state).to eq(PollableJobModel::FAILED_STATE)
          end
        end

        context 'when sio type is not create' do
          it 'does not re-enqueue' do
            scenario = make_stuck_scenario(sio_type: 'update')
            job.perform
            expect(scenario[:pjob].reload.state).to eq(PollableJobModel::FAILED_STATE)
          end
        end

        context 'when sio created_at is beyond the max polling window' do
          it 'does not re-enqueue' do
            scenario = make_stuck_scenario(sio_created_at: Time.now - (max_poll_duration_minutes + 1).minutes)
            job.perform
            expect(scenario[:pjob].reload.state).to eq(PollableJobModel::FAILED_STATE)
          end
        end

        context 'when delayed_job.failed_at is nil (job still running or locked)' do
          it 'does not re-enqueue' do
            scenario = make_stuck_scenario(dj_failed_at: nil)
            job.perform
            expect(scenario[:pjob].reload.state).to eq(PollableJobModel::FAILED_STATE)
          end
        end

        context 'when pollable job state is COMPLETE' do
          it 'does not re-enqueue' do
            scenario = make_stuck_scenario(pjob_state: PollableJobModel::COMPLETE_STATE)
            job.perform
            expect(scenario[:pjob].reload.state).to eq(PollableJobModel::COMPLETE_STATE)
          end
        end

        context 'when pollable job state is PROCESSING' do
          it 'does not re-enqueue' do
            scenario = make_stuck_scenario(pjob_state: PollableJobModel::PROCESSING_STATE)
            job.perform
            expect(scenario[:pjob].reload.state).to eq(PollableJobModel::PROCESSING_STATE)
          end
        end

        context 'when pollable job operation is not service_instance.create' do
          it 'does not re-enqueue' do
            scenario = make_stuck_scenario
            scenario[:pjob].update(operation: 'service_instance.update')
            job.perform
            expect(scenario[:pjob].reload.state).to eq(PollableJobModel::FAILED_STATE)
          end
        end

        context 'when a job is stuck with state FAILED' do
          it 'calls reenqueue' do
            scenario = make_stuck_scenario
            expect_any_instance_of(described_class).to receive(:reenqueue).with(scenario[:pjob].guid, anything)
            job.perform
          end
        end

        context 'when a job is stuck with state POLLING' do
          it 'calls reenqueue (covers DB flip before failure hook could write FAILED)' do
            scenario = make_stuck_scenario(pjob_state: PollableJobModel::POLLING_STATE)
            expect_any_instance_of(described_class).to receive(:reenqueue).with(scenario[:pjob].guid, anything)
            job.perform
          end
        end

        context 'when there are multiple stuck jobs within the batch size' do
          it 'calls reenqueue for each' do
            3.times { make_stuck_scenario }
            expect_any_instance_of(described_class).to receive(:reenqueue).exactly(3).times
            job.perform
          end
        end

        context 'when there are more stuck jobs than the batch size (10)' do
          it 'processes only up to 10 jobs per run' do
            11.times { make_stuck_scenario }
            expect_any_instance_of(described_class).to receive(:reenqueue).exactly(10).times
            job.perform
          end
        end
      end

      describe '#reenqueue' do
        let(:inner_job) { instance_double(Jobs::ReoccurringJob) }

        before do
          allow(Jobs::Enqueuer).to receive(:unwrap_job).and_return(inner_job)
          allow(inner_job).to receive(:enqueue_next_job)
        end

        it 'resets pjob to POLLING state and clears cf_api_error' do
          scenario = make_stuck_scenario
          scenario[:pjob].update(cf_api_error: 'some error')

          job.send(:reenqueue, scenario[:pjob].guid, scenario[:delayed_job])

          expect(scenario[:pjob].reload.state).to eq(PollableJobModel::POLLING_STATE)
          expect(scenario[:pjob].reload.cf_api_error).to be_nil
        end

        it 'calls enqueue_next_job on the unwrapped inner job' do
          scenario = make_stuck_scenario

          expect(inner_job).to receive(:enqueue_next_job).with(instance_of(PollableJobModel))

          job.send(:reenqueue, scenario[:pjob].guid, scenario[:delayed_job])
        end

        context 'when another process already re-enqueued the job (delayed_job_guid changed)' do
          it 'skips without raising and does not call enqueue_next_job' do
            scenario = make_stuck_scenario
            scenario[:pjob].update(delayed_job_guid: 'some-other-guid')

            expect(inner_job).not_to receive(:enqueue_next_job)
            expect { job.send(:reenqueue, scenario[:pjob].guid, scenario[:delayed_job]) }.not_to raise_error
          end
        end
      end
    end
  end
end
