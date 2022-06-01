require 'spec_helper'

RSpec.describe 'Metrics' do
  let(:user) { VCAP::CloudController::User.make }
  let(:user_header) { headers_for(user) }
  let(:threadqueue) { double(EventMachine::Queue, size: 20, num_waiting: 0) }
  let(:resultqueue) { double(EventMachine::Queue, size: 0, num_waiting: 1) }

  before do
    # locator = CloudController::DependencyLocator.instance
    # allow(locator).to receive(:prometheus_updater).and_return(VCAP::CloudController::Metrics::PrometheusUpdater.new(Prometheus::Client::Registry.new))
    allow(EventMachine).to receive(:connection_count).and_return(123)

    allow(EventMachine).to receive(:instance_variable_get) do |instance_var|
      case instance_var
      when :@threadqueue
        threadqueue
      when :@resultqueue
        resultqueue
      else
        raise "Unexpected call: #{instance_var}"
      end
    end
  end

  it 'succeeds' do
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
      if !cc_total_users.nil?
        cc_total_users.set(0)
      end

      # Prometheus::Client::Config::data_store = nil
      10.times do
        VCAP::CloudController::User.make
      end
    end

    it 'reports the total number of users' do
      get '/internal/v4/metrics', nil

      expect(last_response.status).to eq 200

      expect(last_response.body).to include('cc_total_users 10.0')
    end
  end

  context 'cc_vitals' do
    it 'reports vitals' do
      get '/internal/v4/metrics', nil

      expect(last_response.body).to match(/cc_vitals_num_cores [1-9][0-9]*\.\d+/)
      expect(last_response.body).to match(/cc_vitals_uptime [0-9][0-9]*\.\d+/)
      expect(last_response.body).to match(/cc_vitals_cpu [1-9][0-9]*\.\d+/)
      expect(last_response.body).to match(/cc_vitals_mem_bytes [1-9][0-9]*\.\d+/)
      expect(last_response.body).to match(/cc_vitals_cpu_load_avg [0-9][0-9]*\.\d+/)
      expect(last_response.body).to match(/cc_vitals_mem_used_bytes [1-9][0-9]*\.\d+/)
      expect(last_response.body).to match(/cc_vitals_mem_free_bytes [1-9][0-9]*\.\d+/)
    end
  end

  context 'cc_job_queue_length' do
    # NOTE: Because there is no easy way to enqueue a job that will
    #       stick around for long enough to appear in the metrics,
    #       we're only testing that the metric is emitted in the output.
    #       If you can figure out how to actually get a job enqueued that
    #       will show up in the "job queue length" metric, please do update
    #       the test!
    it 'includes job queue length metric in output' do
      get '/internal/v4/metrics', nil

      expect(last_response.body).to match(/cc_job_queue_length_cc_api_0 [0-9][0-9]*\.\d+/)
      expect(last_response.body).to match(/cc_job_queue_length_total [0-9][0-9]*\.\d+/)
    end
  end

  context 'cc_thread_info' do
    it 'reports thread info' do
      get '/internal/v4/metrics', nil

      expect(last_response.body).to match(/cc_thread_info_thread_count [0-9][0-9]*\.\d+/)
      expect(last_response.body).to match(/cc_thread_info_event_machine_connection_count [0-9][0-9]*\.\d+/)
      expect(last_response.body).to match(/cc_thread_info_event_machine_threadqueue_size [0-9][0-9]*\.\d+/)
      expect(last_response.body).to match(/cc_thread_info_event_machine_threadqueue_num_waiting [0-9][0-9]*\.\d+/)
      expect(last_response.body).to match(/cc_thread_info_event_machine_resultqueue_size [0-9][0-9]*\.\d+/)
      expect(last_response.body).to match(/cc_thread_info_event_machine_resultqueue_num_waiting [0-9][0-9]*\.\d+/)
    end
  end

  context 'cc_failed_job_count' do
    it 'reports failed job count' do
      get '/internal/v4/metrics', nil

      expect(last_response.body).to match(/cc_failed_job_count_cc_api_0 [0-9][0-9]*\.\d+/)
      expect(last_response.body).to match(/cc_failed_job_count_total [0-9][0-9]*\.\d+/)
    end
  end

  context 'cc_log_count' do
    it 'reports log counts' do
      get '/internal/v4/metrics', nil

      expect(last_response.body).to match(/cc_log_count_off [0-9][0-9]*\.\d+/)
      expect(last_response.body).to match(/cc_log_count_fatal [0-9][0-9]*\.\d+/)
      expect(last_response.body).to match(/cc_log_count_error [0-9][0-9]*\.\d+/)
      expect(last_response.body).to match(/cc_log_count_warn [0-9][0-9]*\.\d+/)
      expect(last_response.body).to match(/cc_log_count_info [0-9][0-9]*\.\d+/)
      expect(last_response.body).to match(/cc_log_count_debug1 [0-9][0-9]*\.\d+/)
      expect(last_response.body).to match(/cc_log_count_debug2 [0-9][0-9]*\.\d+/)
      expect(last_response.body).to match(/cc_log_count_all [0-9][0-9]*\.\d+/)
    end
  end

  context 'cc_task_stats' do
    it 'reports task stats' do
      get '/internal/v4/metrics', nil

      expect(last_response.body).to match(/cc_tasks_running_count [0-9][0-9]*\.\d+/)
      expect(last_response.body).to match(/cc_tasks_running_memory_in_mb [0-9][0-9]*\.\d+/)
    end
  end

  context 'cc_deploying_count' do
    it 'reports deploying_count' do
      get '/internal/v4/metrics', nil

      expect(last_response.body).to match(/cc_deployments_deploying [0-9][0-9]*\.\d+/)
    end
  end
end
