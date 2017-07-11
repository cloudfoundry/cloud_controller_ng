require 'spec_helper'
require 'jobs/pollable_job_wrapper'

module VCAP::CloudController::Jobs
  RSpec.describe PollableJobWrapper do
    let(:job) { double(job_name_in_configuration: 'my-job', max_attempts: 2, perform: nil) }
    let(:pollable_job) { PollableJobWrapper.new(job) }

    describe '#perform' do
      it 'runs the provided job' do
        expect(job).to receive(:perform)
        pollable_job.perform
      end
    end

    describe 'delayed job hooks' do
      # using a real job as DelayedJob has trouble marshalling doubles
      let(:delete_action) { VCAP::CloudController::DropletDelete.new('fake') }
      let(:job) { DeleteActionJob.new(VCAP::CloudController::DropletModel, 'fake', delete_action) }

      it 'creates a job record and marks the job model as completed' do
        enqueued_job = VCAP::CloudController::Jobs::Enqueuer.new(pollable_job).enqueue

        job_record = VCAP::CloudController::PollableJobModel.find(delayed_job_guid: enqueued_job.guid)
        expect(job_record).to_not be_nil, "Expected to find PollableJobModel with delayed_job_guid '#{enqueued_job.guid}', but did not"
        expect(job_record.state).to eq('PROCESSING')
        expect(job_record.operation).to eq('droplet.delete')
        expect(job_record.resource_guid).to eq('fake')
        expect(job_record.resource_type).to eq('droplet')

        execute_all_jobs(expected_successes: 1, expected_failures: 0)

        expect(job_record.reload.state).to eq('COMPLETE')
      end

      context 'when the job fails' do
        before do
          allow_any_instance_of(VCAP::CloudController::Jobs::DeleteActionJob).to receive(:perform).and_raise
        end

        context 'when there is an associated job model' do
          it 'marks the job model failed' do
            enqueued_job = VCAP::CloudController::Jobs::Enqueuer.new(pollable_job).enqueue
            job_model = VCAP::CloudController::PollableJobModel.make(delayed_job_guid: enqueued_job.guid, state: 'PROCESSING')

            execute_all_jobs(expected_successes: 0, expected_failures: 1)

            expect(job_model.reload.state).to eq('FAILED')
          end
        end

        context 'when there is NOT an associated job model' do
          it 'does NOT choke' do
            VCAP::CloudController::Jobs::Enqueuer.new(pollable_job).enqueue

            execute_all_jobs(expected_successes: 0, expected_failures: 1)
          end
        end
      end
    end

    context '#max_attempts' do
      it 'delegates to the handler' do
        expect(pollable_job.max_attempts).to eq(2)
      end
    end

    describe '#reschedule_at' do
      before do
        allow(job).to receive(:reschedule_at) do |time, attempts|
          time + attempts
        end
      end

      it 'defers to the inner job' do
        time = Time.now
        attempts = 5
        expect(pollable_job.reschedule_at(time, attempts)).to eq(job.reschedule_at(time, attempts))
      end
    end
  end
end
