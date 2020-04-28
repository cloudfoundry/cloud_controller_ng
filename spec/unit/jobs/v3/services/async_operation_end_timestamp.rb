RSpec.shared_examples 'end_timestamp' do
  let(:max_poll_duration) { VCAP::CloudController::Config.config.get(:broker_client_max_async_poll_duration_minutes) }

  context 'when the job is new' do
    it 'adds the broker_client_max_async_poll_duration_minutes to the current time' do
      now = Time.now
      expected_end_timestamp = now + max_poll_duration.minutes
      Timecop.freeze now do
        expect(job.end_timestamp).to be_within(0.01).of(expected_end_timestamp)
      end
    end
  end

  context 'when the job is fetched from the database' do
    it 'returns the previously computed and persisted end_timestamp' do
      now = Time.now
      expected_end_timestamp = now + max_poll_duration.minutes

      job_id = nil
      Timecop.freeze now do
        enqueued_job = Jobs::Enqueuer.new(job, queue: Jobs::Queues.generic, run_at: Time.now).enqueue
        job_id = enqueued_job.id
      end

      Timecop.freeze(now + 1.day) do
        rehydrated_job = Delayed::Job.first(id: job_id).payload_object.handler.handler
        expect(rehydrated_job.end_timestamp).to be_within(0.01).of(expected_end_timestamp)
      end
    end
  end
end
