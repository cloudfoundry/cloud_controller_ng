require 'spec_helper'

RSpec.describe 'Metrics' do
  let(:user) { VCAP::CloudController::User.make }
  let(:user_header) { headers_for(user) }
  let(:metrics_webserver) { VCAP::CloudController::MetricsWebserver.new }

  delegate :app, to: :metrics_webserver

  before do
    # Force Puma to bind to an ephemeral port (0) to avoid EADDRINUSE
    allow_any_instance_of(Puma::Server).to receive(:add_tcp_listener).and_wrap_original do |m, host, _|
      m.call(host, 0)
    end
    allow_any_instance_of(VCAP::CloudController::Metrics::PeriodicUpdater).to receive(:update_webserver_stats)
    metrics_webserver.start(TestConfig.config_instance)
  end

  after do
    metrics_webserver.stop
  end

  it 'can be called several times' do
    get '/internal/v4/metrics', nil

    expect(last_response.status).to eq 200
    get '/internal/v4/metrics', nil

    expect(last_response.status).to eq 200
    get '/internal/v4/metrics', nil

    expect(last_response.status).to eq 200
  end

  context 'cc_total_users' do
    before do
      cc_total_users = Prometheus::Client.registry.get(:cc_total_users)
      cc_total_users.set(0) unless cc_total_users.nil?

      10.times do
        VCAP::CloudController::User.make
      end
      CloudController::DependencyLocator.instance.periodic_updater.update_user_count
    end

    it 'reports the total number of users' do
      get '/internal/v4/metrics', nil

      expect(last_response.status).to eq 200

      expect(last_response.body).to include('cc_users_total 10.0')
    end
  end

  context 'cc_vitals' do
    it 'reports vitals' do
      CloudController::DependencyLocator.instance.periodic_updater.update_vitals
      get '/internal/v4/metrics', nil

      expect(last_response.body).to match(/cc_vitals_num_cores [1-9][0-9]*\.\d+/)
      expect(last_response.body).to match(/cc_vitals_started_at [0-9][0-9]*\.\d+/)
      expect(last_response.body).to match(/cc_vitals_mem_bytes [1-9][0-9]*\.\d+/)
      expect(last_response.body).to match(/cc_vitals_cpu_load_avg [0-9][0-9]*\.\d+/)
      expect(last_response.body).to match(/cc_vitals_mem_used_bytes [1-9][0-9]*\.\d+/)
      expect(last_response.body).to match(/cc_vitals_mem_free_bytes [1-9][0-9]*\.\d+/)
    end
  end

  context 'cc_job_queue_length' do
    before do
      Delayed::Job.enqueue(VCAP::CloudController::Jobs::Runtime::EventsCleanup.new(1), { queue: 'cc_api_0', run_at: Time.now + 1.day })
      Delayed::Job.enqueue(VCAP::CloudController::Jobs::Runtime::EventsCleanup.new(1), { queue: 'cc_generic', run_at: Time.now + 1.day })

      CloudController::DependencyLocator.instance.periodic_updater.update_job_queue_length
    end

    after do
      Delayed::Job.dataset.delete
    end

    it 'includes job queue length metric labelled for each queue' do
      get '/internal/v4/metrics', nil

      expect(last_response.body).to match(/cc_job_queues_length_total{queue="cc_api_0"} 1\.0/)
      expect(last_response.body).to match(/cc_job_queues_length_total{queue="cc_generic"} 1\.0/)
    end
  end

  context 'cc_job_queue_load' do
    before do
      Delayed::Job.enqueue(VCAP::CloudController::Jobs::Runtime::EventsCleanup.new(1), { queue: 'cc_api_0', run_at: Time.now })
      Delayed::Job.enqueue(VCAP::CloudController::Jobs::Runtime::EventsCleanup.new(1), { queue: 'cc_generic', run_at: Time.now })

      # jobs with run_at in the future should not be counted towards load
      Delayed::Job.enqueue(VCAP::CloudController::Jobs::Runtime::EventsCleanup.new(1), { queue: 'cc_api_0', run_at: Time.now + 1.minute })
      Delayed::Job.enqueue(VCAP::CloudController::Jobs::Runtime::EventsCleanup.new(1), { queue: 'cc_generic', run_at: Time.now + 1.minute })

      CloudController::DependencyLocator.instance.periodic_updater.update_job_queue_load
    end

    after do
      Delayed::Job.dataset.delete
    end

    it 'includes job queue load metric labelled for each queue' do
      get '/internal/v4/metrics', nil

      expect(last_response.body).to match(/cc_job_queues_load_total{queue="cc_api_0"} 1\.0/)
      expect(last_response.body).to match(/cc_job_queues_load_total{queue="cc_generic"} 1\.0/)
    end
  end

  context 'cc_failed_job_count' do
    before do
      Delayed::Job.enqueue(VCAP::CloudController::Jobs::Runtime::EventsCleanup.new(1), { queue: 'cc_api_0', run_at: Time.now + 1.day })
      Delayed::Job.enqueue(VCAP::CloudController::Jobs::Runtime::EventsCleanup.new(1), { queue: 'cc_generic', run_at: Time.now + 1.day })
      Delayed::Job.dataset.update(failed_at: Time.now.utc)

      CloudController::DependencyLocator.instance.periodic_updater.update_failed_job_count
    end

    after do
      Delayed::Job.dataset.delete
    end

    it 'reports failed job count' do
      get '/internal/v4/metrics', nil

      expect(last_response.body).to match(/cc_failed_jobs_total{queue="cc_api_0"} 1\.0/)
      expect(last_response.body).to match(/cc_failed_jobs_total{queue="cc_generic"} 1\.0/)
    end
  end

  context 'cc_task_stats' do
    it 'reports task stats' do
      get '/internal/v4/metrics', nil

      expect(last_response.body).to match(/cc_running_tasks_total [0-9][0-9]*\.\d+/)
      expect(last_response.body).to match(/cc_running_tasks_memory_bytes [0-9][0-9]*\.\d+/)
    end
  end

  context 'cc_deploying_count' do
    it 'reports deploying_count' do
      get '/internal/v4/metrics', nil

      expect(last_response.body).to match(/cc_deployments_in_progress_total [0-9][0-9]*\.\d+/)
    end
  end

  context 'cc_staging_requests_total' do
    it 'reports cc_staging_requests_total' do
      get '/internal/v4/metrics', nil

      expect(last_response.body).to match(/cc_staging_requests_total [0-9][0-9]*\.\d+/)
    end
  end

  context 'cc_staging_succeeded_duration_seconds' do
    it 'reports cc_staging_succeeded_duration_seconds' do
      get '/internal/v4/metrics', nil

      expect(last_response.body).to match(/cc_staging_succeeded_duration_seconds_bucket{le="5"} [0-9][0-9]*\.\d+/)
      expect(last_response.body).to match(/cc_staging_succeeded_duration_seconds_bucket{le="5"} [0-9][0-9]*\.\d+/)
      expect(last_response.body).to match(/cc_staging_succeeded_duration_seconds_bucket{le="10"} [0-9][0-9]*\.\d+/)
      expect(last_response.body).to match(/cc_staging_succeeded_duration_seconds_bucket{le="30"} [0-9][0-9]*\.\d+/)
      expect(last_response.body).to match(/cc_staging_succeeded_duration_seconds_bucket{le="60"} [0-9][0-9]*\.\d+/)
      expect(last_response.body).to match(/cc_staging_succeeded_duration_seconds_bucket{le="300"} [0-9][0-9]*\.\d+/)
      expect(last_response.body).to match(/cc_staging_succeeded_duration_seconds_bucket{le="600"} [0-9][0-9]*\.\d+/)
      expect(last_response.body).to match(/cc_staging_succeeded_duration_seconds_bucket{le="890"} [0-9][0-9]*\.\d+/)
      expect(last_response.body).to match(/cc_staging_succeeded_duration_seconds_bucket{le="\+Inf"} [0-9][0-9]*\.\d+/)

      expect(last_response.body).to match(/cc_staging_succeeded_duration_seconds_sum [0-9][0-9]*\.\d+/)
      expect(last_response.body).to match(/cc_staging_succeeded_duration_seconds_count [0-9][0-9]*\.\d+/)
    end
  end

  context 'cc_staging_failed_duration_seconds' do
    it 'reports cc_staging_failed_duration_seconds' do
      get '/internal/v4/metrics', nil

      expect(last_response.body).to match(/cc_staging_failed_duration_seconds_bucket{le="5"} [0-9][0-9]*\.\d+/)
      expect(last_response.body).to match(/cc_staging_failed_duration_seconds_bucket{le="5"} [0-9][0-9]*\.\d+/)
      expect(last_response.body).to match(/cc_staging_failed_duration_seconds_bucket{le="10"} [0-9][0-9]*\.\d+/)
      expect(last_response.body).to match(/cc_staging_failed_duration_seconds_bucket{le="30"} [0-9][0-9]*\.\d+/)
      expect(last_response.body).to match(/cc_staging_failed_duration_seconds_bucket{le="60"} [0-9][0-9]*\.\d+/)
      expect(last_response.body).to match(/cc_staging_failed_duration_seconds_bucket{le="300"} [0-9][0-9]*\.\d+/)
      expect(last_response.body).to match(/cc_staging_failed_duration_seconds_bucket{le="600"} [0-9][0-9]*\.\d+/)
      expect(last_response.body).to match(/cc_staging_failed_duration_seconds_bucket{le="890"} [0-9][0-9]*\.\d+/)
      expect(last_response.body).to match(/cc_staging_failed_duration_seconds_bucket{le="\+Inf"} [0-9][0-9]*\.\d+/)

      expect(last_response.body).to match(/cc_staging_failed_duration_seconds_sum [0-9][0-9]*\.\d+/)
      expect(last_response.body).to match(/cc_staging_failed_duration_seconds_count [0-9][0-9]*\.\d+/)
    end
  end

  context 'cc_requests_completed_total' do
    it 'reports cc_requests_completed_total' do
      get '/internal/v4/metrics', nil

      expect(last_response.body).to match(/cc_requests_completed_total [0-9][0-9]*\.\d+/)
    end
  end

  context 'cc_requests_outstanding_total' do
    it 'reports cc_requests_outstanding_total' do
      get '/internal/v4/metrics', nil

      expect(last_response.body).to match(/cc_requests_outstanding_total [0-9][0-9]*\.\d+/)
    end
  end
end
