require 'spec_helper'

RSpec.describe 'Metrics' do
  let(:user) { VCAP::CloudController::User.make }
  let(:user_header) { headers_for(user) }

  let(:metrics_webserver) { VCAP::CloudController::MetricsWebserver.new }
  delegate :app, to: :metrics_webserver

  # FIXME: PrometheusUpdater methods are not called -> returned values are almost all 0
  before do
    prom_client = Prometheus::Client::Registry.new
    Prometheus::Client.config.data_store = Prometheus::Client::DataStores::DirectFileStore.new(dir: Dir.mktmpdir)
    VCAP::CloudController::Metrics::PrometheusUpdater.new(registry: prom_client)

    metrics_webserver.start(TestConfig.config_instance)
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
    end

    it 'reports the total number of users' do
      get '/internal/v4/metrics', nil

      expect(last_response.status).to eq 200

      expect(last_response.body).to include('cc_users_total 10.0')
    end
  end

  context 'cc_vitals' do
    it 'reports vitals' do
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

  context 'cc_job_queue_load_not_ready_to_run_now' do
    before do
      Delayed::Job.enqueue(VCAP::CloudController::Jobs::Runtime::EventsCleanup.new(1), { queue: 'cc_api_0', run_at: Time.now + 1.minute })
      Delayed::Job.enqueue(VCAP::CloudController::Jobs::Runtime::EventsCleanup.new(1), { queue: 'cc_generic', run_at: Time.now + 1.minute })
    end

    after do
      Delayed::Job.dataset.delete
    end

    it 'includes job queue load metric labelled for each queue' do
      get '/internal/v4/metrics', nil

      expect(last_response.body).to match(/cc_job_queues_load_total{queue="cc_api_0"} 0\.0/)
      expect(last_response.body).to match(/cc_job_queues_load_total{queue="cc_generic"} 0\.0/)
    end
  end

  context 'cc_failed_job_count' do
    before do
      Delayed::Job.enqueue(VCAP::CloudController::Jobs::Runtime::EventsCleanup.new(1), { queue: 'cc_api_0', run_at: Time.now + 1.day })
      Delayed::Job.enqueue(VCAP::CloudController::Jobs::Runtime::EventsCleanup.new(1), { queue: 'cc_generic', run_at: Time.now + 1.day })

      Delayed::Job.dataset.update(failed_at: Time.now.utc)
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
