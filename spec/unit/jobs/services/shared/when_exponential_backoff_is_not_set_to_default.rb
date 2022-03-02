RSpec.shared_examples 'when exponential backoff is not set to default' do
  context 'when exponential backoff is not set to default' do
    it 'calculates the polling intervals based on the default interval and the exponential backoff rate' do
      TestConfig.config[:broker_client_async_poll_exponential_backoff_rate] = 2.0
      enqueued_time = 0

      Timecop.freeze do
        run_job(job)
        enqueued_time = Time.now
      end

      [60, 180, 420, 900, 1860].each do |seconds|
        Timecop.freeze((seconds - 1).seconds.after(enqueued_time)) do
          execute_all_jobs(expected_successes: 0, expected_failures: 0)
        end

        Timecop.freeze((seconds + 1).seconds.after(enqueued_time)) do
          execute_all_jobs(expected_successes: 1, expected_failures: 0)
        end
      end
    end

    it 'calculates the polling intervals based on the configured interval and the exponential backoff rate' do
      TestConfig.config[:broker_client_async_poll_exponential_backoff_rate] = 2.0
      TestConfig.config[:broker_client_default_async_poll_interval_seconds] = 10
      enqueued_time = 0

      Timecop.freeze do
        run_job(job)
        enqueued_time = Time.now
      end

      [10, 30, 70, 150, 310].each do |seconds|
        Timecop.freeze((seconds - 1).seconds.after(enqueued_time)) do
          execute_all_jobs(expected_successes: 0, expected_failures: 0)
        end

        Timecop.freeze((seconds + 1).seconds.after(enqueued_time)) do
          execute_all_jobs(expected_successes: 1, expected_failures: 0)
        end
      end
    end

    it 'takes the exponential backoff into account when checking whether the next run would exceed the maximum duration' do
      TestConfig.config[:broker_client_async_poll_exponential_backoff_rate] = 1.3
      TestConfig.config[:broker_client_max_async_poll_duration_minutes] = 60

      job.retry_number = 10
      Timecop.freeze(Time.now + 3384.321.ceil.seconds) do
        run_job(job)

        expect(last_operation.state).to eq('failed')
        expect(last_operation.description).to match(/Service Broker failed/)
      end
    end
  end
end
