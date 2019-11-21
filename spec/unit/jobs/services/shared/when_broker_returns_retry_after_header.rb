RSpec.shared_examples 'when brokers return Retry-After header' do |last_operation_method_name|
  context 'when brokers return Retry-After header' do
    let(:state) { 'in progress' }
    let(:default_polling_interval) { VCAP::CloudController::Config.config.get(:broker_client_default_async_poll_interval_seconds) }
    let(:last_operation_response) { { last_operation: { state: state, description: description }, retry_after: broker_polling_interval } }

    before do
      allow(client).to receive(last_operation_method_name).and_return(last_operation_response)
    end

    context 'when the broker returns interval' do
      context 'when the interval is greater than the default configuration' do
        let(:broker_polling_interval) { default_polling_interval * 2 }

        it 'the polling interval should be the one broker returned' do
          Timecop.freeze(Time.now)
          first_run_time = Time.now

          VCAP::CloudController::Jobs::Enqueuer.new(job, { queue: VCAP::CloudController::Jobs::Queues.generic, run_at: first_run_time }).enqueue
          execute_all_jobs(expected_successes: 1, expected_failures: 0)
          expect(Delayed::Job.count).to eq(1)

          run_time_default_interval = first_run_time + default_polling_interval.seconds + 1.second
          Timecop.travel(run_time_default_interval) do
            execute_all_jobs(expected_successes: 0, expected_failures: 0)
          end

          run_time_broker_interval = first_run_time + broker_polling_interval.seconds + 1.second
          Timecop.travel(run_time_broker_interval) do
            execute_all_jobs(expected_successes: 1, expected_failures: 0)
          end
        end
      end

      context 'when the interval is less than the default configuration' do
        let(:broker_polling_interval) { default_polling_interval / 2 }

        it 'the polling interval should be the default specified in the configuration' do
          Timecop.freeze(Time.now)
          first_run_time = Time.now

          VCAP::CloudController::Jobs::Enqueuer.new(job, { queue: VCAP::CloudController::Jobs::Queues.generic, run_at: first_run_time }).enqueue
          execute_all_jobs(expected_successes: 1, expected_failures: 0)
          expect(Delayed::Job.count).to eq(1)

          run_time_default_interval = first_run_time + default_polling_interval.seconds + 1.second
          Timecop.travel(run_time_default_interval) do
            execute_all_jobs(expected_successes: 1, expected_failures: 0)
          end
        end
      end

      context 'when the interval is greater than the max value (24 hours)' do
        let(:broker_polling_interval) { 24.hours.seconds + 1.minutes }

        it 'the polling interval should not exceed the max' do
          Timecop.freeze(Time.now)
          first_run_time = Time.now

          VCAP::CloudController::Jobs::Enqueuer.new(job, { queue: VCAP::CloudController::Jobs::Queues.generic, run_at: first_run_time }).enqueue
          execute_all_jobs(expected_successes: 1, expected_failures: 0)
          expect(Delayed::Job.count).to eq(1)

          run_time_max_interval = first_run_time + 24.hours + 1.second
          Timecop.travel(run_time_max_interval) do
            execute_all_jobs(expected_successes: 1, expected_failures: 0)
          end
        end
      end
    end
  end
end
