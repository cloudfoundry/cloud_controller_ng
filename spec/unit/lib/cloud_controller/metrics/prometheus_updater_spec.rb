require 'spec_helper'
require 'cloud_controller/metrics/prometheus_updater'

module VCAP::CloudController::Metrics
  RSpec.describe PrometheusUpdater do
    let(:updater) { PrometheusUpdater.new(prom_client) }
    let(:tmpdir) { Dir.mktmpdir }
    let(:prom_client) do
      Prometheus::Client.config.data_store = Prometheus::Client::DataStores::DirectFileStore.new(dir: tmpdir)
      Prometheus::Client::Registry.new
    end

    describe 'Prometheus creation guards work correctly' do
      # This might look to be a duplicate of 'records the current number of deployments that are DEPLOYING'
      # below, but it tests that at least one of the metric updating functions can be called multiple times
      # without failures. Because we are re-creating the Prometheus Client Registry before every test, we
      # need to have at least one test that ensures that operations on a used registry won't fail.
      #
      # Because the PrometheusUpdater is designed so that all of the functionality that calls out to Prometheus is
      # contained within a few short functions that follow the same obvious "Create the metric if it doesn't exist
      # and then update the metric" pattern, the expectation is that future folks that work on the code will
      # be unlikely to unintentionally remove the "create the metric if it doesn't exist" guard, and will also
      # be unlikely to leave the guard out if they need to create a function that works with another Prometheus
      # metric datatype.
      it 'does not explode when the update function is called more than once' do
        expected_deploying_count = 7

        updater.update_deploying_count(expected_deploying_count)
        metric = prom_client.metrics.find { |m| m.name == :cc_deployments_in_progress_total }
        expect(metric).to be_present
        expect(metric.get).to eq 7

        updater.update_deploying_count(expected_deploying_count)
        metric = prom_client.metrics.find { |m| m.name == :cc_deployments_in_progress_total }
        expect(metric).to be_present
        expect(metric.get).to eq 7
      end
    end

    describe '#update_deploying_count' do
      it 'records the current number of deployments that are DEPLOYING' do
        expected_deploying_count = 7

        updater.update_deploying_count(expected_deploying_count)
        metric = prom_client.metrics.find { |m| m.name == :cc_deployments_in_progress_total }
        expect(metric).to be_present
        expect(metric.get).to eq 7
      end
    end

    describe '#update_user_count' do
      it 'records number of users' do
        expected_user_count = 5

        updater.update_user_count(expected_user_count)

        metric = prom_client.metrics.find { |m| m.name == :cc_users_total }
        expect(metric).to be_present
        expect(metric.get).to eq 5
      end
    end

    describe '#update_job_queue_length' do
      it 'records the length of the delayed job queues and total' do
        expected_local_length   = 5
        expected_generic_length = 6

        pending_job_count_by_queue = {
          cc_local: expected_local_length,
          cc_generic: expected_generic_length
        }

        updater.update_job_queue_length(pending_job_count_by_queue)

        metric = prom_client.get :cc_job_queues_length_total
        expect(metric.get(labels: { queue: 'cc_local' })).to eq 5
        expect(metric.get(labels: { queue: 'cc_generic' })).to eq 6
      end
    end

    describe '#update_job_queue_load' do
      it 'records the load of the delayed job queues and total' do
        expected_local_load   = 5
        expected_generic_load = 6

        pending_job_load_by_queue = {
          cc_local: expected_local_load,
          cc_generic: expected_generic_load
        }

        updater.update_job_queue_load(pending_job_load_by_queue)

        metric = prom_client.get :cc_job_queues_load_total
        expect(metric.get(labels: { queue: 'cc_local' })).to eq 5
        expect(metric.get(labels: { queue: 'cc_generic' })).to eq 6
      end
    end

    describe '#update_failed_job_count' do
      it 'records the number of failed jobs in the delayed job queue and the total to statsd' do
        expected_local_length   = 5
        expected_generic_length = 6

        failed_jobs_by_queue = {
          cc_local: expected_local_length,
          cc_generic: expected_generic_length
        }

        updater.update_failed_job_count(failed_jobs_by_queue)

        metric = prom_client.get :cc_failed_jobs_total
        expect(metric.get(labels: { queue: 'cc_local' })).to eq 5
        expect(metric.get(labels: { queue: 'cc_generic' })).to eq 6
      end
    end

    describe '#update_thread_info_thin' do
      it 'contains EventMachine data' do
        thread_info = {
          thread_count: 5,
          event_machine: {
            connection_count: 10,
            threadqueue: {
              size: 19,
              num_waiting: 2
            },
            resultqueue: {
              size: 8,
              num_waiting: 1
            }
          }
        }

        updater.update_thread_info_thin(thread_info)

        metric = prom_client.metrics.find { |m| m.name == :cc_thread_info_thread_count }
        expect(metric.get).to eq 5

        metric = prom_client.metrics.find { |m| m.name == :cc_thread_info_event_machine_connection_count }
        expect(metric.get).to eq 10

        metric = prom_client.metrics.find { |m| m.name == :cc_thread_info_event_machine_threadqueue_size }
        expect(metric.get).to eq 19

        metric = prom_client.metrics.find { |m| m.name == :cc_thread_info_event_machine_threadqueue_num_waiting }
        expect(metric.get).to eq 2

        metric = prom_client.metrics.find { |m| m.name == :cc_thread_info_event_machine_resultqueue_size }
        expect(metric.get).to eq 8

        metric = prom_client.metrics.find { |m| m.name == :cc_thread_info_event_machine_resultqueue_num_waiting }
        expect(metric.get).to eq 1
      end
    end

    describe '#update_vitals' do
      it 'updates vitals' do
        vitals = {
          started_at: 1_699_522_477.0,
          cpu_load_avg: 0.5,
          mem_used_bytes: 542,
          mem_free_bytes: 927,
          mem_bytes: 1,
          num_cores: 4
        }

        updater.update_vitals(vitals)

        metric = prom_client.metrics.find { |m| m.name == :cc_vitals_started_at }
        expect(metric.get).to eq 1_699_522_477.0

        metric = prom_client.metrics.find { |m| m.name == :cc_vitals_cpu_load_avg }
        expect(metric.get).to eq 0.5

        metric = prom_client.metrics.find { |m| m.name == :cc_vitals_mem_used_bytes }
        expect(metric.get).to eq 542

        metric = prom_client.metrics.find { |m| m.name == :cc_vitals_mem_free_bytes }
        expect(metric.get).to eq 927

        metric = prom_client.metrics.find { |m| m.name == :cc_vitals_mem_bytes }
        expect(metric.get).to eq 1

        metric = prom_client.metrics.find { |m| m.name == :cc_vitals_num_cores }
        expect(metric.get).to eq 4
      end
    end

    describe '#update_task_stats' do
      it 'records the number of running tasks and task memory' do
        updater.update_task_stats(5, 512)

        metric = prom_client.metrics.find { |m| m.name == :cc_running_tasks_total }
        expect(metric.get).to eq 5

        metric = prom_client.metrics.find { |m| m.name == :cc_running_tasks_memory_bytes }
        expect(metric.get).to eq 512
      end
    end

    describe '#update_webserver_stats_puma' do
      before do
        TestConfig.override(webserver: 'puma')
      end

      it 'contains Puma stats' do
        worker_count = 2
        worker_stats = [
          { started_at: 1_701_263_705, index: 0, pid: 123, thread_count: 1, backlog: 0 },
          { started_at: 1_701_263_710, index: 1, pid: 234, thread_count: 2, backlog: 1 }
        ]

        updater.update_webserver_stats_puma(worker_count, worker_stats)

        metric = prom_client.metrics.find { |m| m.name == :cc_puma_worker_count }
        expect(metric.get).to eq(2)

        metric = prom_client.metrics.find { |m| m.name == :cc_puma_worker_started_at }
        expect(metric.get(labels: { index: 0, pid: 123 })).to eq(1_701_263_705)
        expect(metric.get(labels: { index: 1, pid: 234 })).to eq(1_701_263_710)

        metric = prom_client.metrics.find { |m| m.name == :cc_puma_worker_thread_count }
        expect(metric.get(labels: { index: 0, pid: 123 })).to eq(1)
        expect(metric.get(labels: { index: 1, pid: 234 })).to eq(2)

        metric = prom_client.metrics.find { |m| m.name == :cc_puma_worker_backlog }
        expect(metric.get(labels: { index: 0, pid: 123 })).to eq(0)
        expect(metric.get(labels: { index: 1, pid: 234 })).to eq(1)
      end
    end

    describe '#start_staging_request_received' do
      it 'increments "cc_staging_requests_total"' do
        updater.start_staging_request_received

        metric = prom_client.metrics.find { |m| m.name == :cc_staging_requests_total }
        expect(metric.get).to eq 1

        updater.start_staging_request_received

        metric = prom_client.metrics.find { |m| m.name == :cc_staging_requests_total }
        expect(metric.get).to eq 2
      end
    end

    describe '#report_staging_success_metrics' do
      it 'records staging success metrics' do
        # 20 seconds
        duration_ns = 20 * 1e9

        updater.report_staging_success_metrics(duration_ns)

        metric = prom_client.get :cc_staging_succeeded_duration_seconds
        expect(metric.get).to eq({ '5' => 0.0, '10' => 0.0, '30' => 1.0, '60' => 1.0, '300' => 1.0, '600' => 1.0, '890' => 1.0, 'sum' => 20.0, '+Inf' => 1.0 })
      end
    end

    describe '#report_staging_failure_metrics' do
      it 'emits staging failure metrics' do
        # 900 seconds
        duration_ns = 900 * 1e9

        updater.report_staging_failure_metrics(duration_ns)

        metric = prom_client.get :cc_staging_failed_duration_seconds
        expect(metric.get).to eq({ '5' => 0.0, '10' => 0.0, '30' => 0.0, '60' => 0.0, '300' => 0.0, '600' => 0.0, '890' => 0.0, 'sum' => 900.0, '+Inf' => 1.0 })
      end
    end
  end
end
