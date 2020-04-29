RSpec.shared_examples 'end_timestamp' do
  let(:cc_config_max_polling_duration) { 10080 }

  before do
    config_override = {
      broker_client_max_async_poll_duration_minutes: cc_config_max_polling_duration,
    }
    TestConfig.override(config_override)
  end

  context 'when the job is new' do
    context 'when the plan does not define a max_polling_duration' do
      it 'adds the broker_client_max_async_poll_duration_minutes to the current time' do
        now = Time.now
        expected_end_timestamp = now + cc_config_max_polling_duration.minutes
        Timecop.freeze now do
          expect(job.end_timestamp).to be_within(0.01).of(expected_end_timestamp)
        end
      end
    end

    context 'when the plan defines a max_polling duration' do
      let(:plan_maximum_polling_duration) {}

      before do
        service_plan.maximum_polling_duration = plan_maximum_polling_duration
        service_plan.save
      end

      context 'the plan max_polling_duration is shorter than the platform config' do
        let(:plan_maximum_polling_duration) { 360 } # in seconds

        it 'adds the plan max_polling_duration to the current time' do
          now = Time.now
          expected_end_timestamp = now + plan_maximum_polling_duration.seconds

          Timecop.freeze now do
            expect(job.end_timestamp).to be_within(0.01).of(expected_end_timestamp)
          end
        end
      end

      context 'the plan max_polling_duration is longer than the platform config' do
        let(:plan_maximum_polling_duration) { 36000000 } # in seconds

        it 'adds the broker_client_max_async_poll_duration_minutes to the current time' do
          now = Time.now
          expected_end_timestamp = now + cc_config_max_polling_duration.minutes
          Timecop.freeze now do
            expect(job.end_timestamp).to be_within(0.01).of(expected_end_timestamp)
          end
        end
      end

      context 'when there is a database error in fetching the plan' do
        it 'should set end_timestamp to config value' do
          allow(VCAP::CloudController::ManagedServiceInstance).to receive(:first) do |e|
            raise Sequel::Error.new(e)
          end
          Timecop.freeze(Time.now)
          expect(job.end_timestamp).to eq(Time.now + cc_config_max_polling_duration.minutes)
        end
      end
    end
  end

  context 'when the job is fetched from the database' do
    it 'returns the previously computed and persisted end_timestamp' do
      now = Time.now
      expected_end_timestamp = now + cc_config_max_polling_duration.minutes

      job_id = nil
      Timecop.freeze now do
        enqueued_job = VCAP::CloudController::Jobs::Enqueuer.new(
          job,
          queue: VCAP::CloudController::Jobs::Queues.generic,
          run_at: Time.now).enqueue
        job_id = enqueued_job.id
      end

      Timecop.freeze(now + 1.day) do
        rehydrated_job = Delayed::Job.first(id: job_id).payload_object.handler.handler
        expect(rehydrated_job.end_timestamp).to be_within(0.01).of(expected_end_timestamp)
      end
    end
  end
end
