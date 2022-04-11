require 'spec_helper'
require 'cloud_controller/metrics/prometheus_updater'

# There are a few things to NOTE here:
# 1) We're adding this function because the Prometheus Client Registry
#    is interpreter-global state, so changes that happen in one test will
#    absolutely affect other tests, unless the test author has taken pains
#    to carefully clean up their changes.
# 2) In our CI, tests are run in parallel to speed up execution. At the time
#    of this writing (2022-05-03), we use the `grosser/parallel_tests` gem to
#    run tests in parallel. This gem uses the `grosser/parallel` gem to distribute
#    work which runs workloads in separate subprocesses, rather than threads
#    in the same interpreter process.
#    You will notice that we call this function that we created in a top-level
#    `before` block a little bit later in this file, and _also_ that we mention
#    above that the Registry is interpeter-global state. Because our
#    test-parallelizer uses subprocesses to distribute its work, and also does
#    not interleave tests from one file with tests from another, the registry
#    recreation that we're doing here will be restricted to the tests in _this_
#    file and will not leak out into other files.
# 3) So, if you see weird or unreliable behavior out of the Registry when running
#    specs (this would probably be stuff like "metric values are sometimes not what
#    they should be"), check to see if our test parallelizer is still using
#    subprocesses, or if it has switched to threads and runs everything in one
#    interpreter.
module Prometheus
  module Client
    def self.recreate_registry
      @registry = Prometheus::Client::Registry.new
    end
  end
end

module VCAP::CloudController::Metrics
  RSpec.describe PrometheusUpdater do
    let(:updater) { PrometheusUpdater.new(prom_client) }
    let(:prom_client) { Prometheus::Client.registry }

    before do
      Prometheus::Client.recreate_registry
    end

    describe 'Promethus creation guards work correctly' do
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
        metric = prom_client.metrics.find { |m| m.name == :cc_deployments_deploying }
        expect(metric).to be_present
        expect(metric.get).to eq 7

        updater.update_deploying_count(expected_deploying_count)
        metric = prom_client.metrics.find { |m| m.name == :cc_deployments_deploying }
        expect(metric).to be_present
        expect(metric.get).to eq 7
      end
    end

    describe '#update_deploying_count' do
      it 'records the current number of deployments that are DEPLOYING' do
        expected_deploying_count = 7

        updater.update_deploying_count(expected_deploying_count)
        metric = prom_client.metrics.find { |m| m.name == :cc_deployments_deploying }
        expect(metric).to be_present
        expect(metric.get).to eq 7
      end
    end

    describe '#update_user_count' do
      it 'records number of users' do
        expected_user_count = 5

        updater.update_user_count(expected_user_count)

        metric = prom_client.metrics.find { |m| m.name == :cc_total_users }
        expect(metric).to be_present
        expect(metric.get).to eq 5
      end
    end

    describe '#update_job_queue_length' do
      it 'records the length of the delayed job queues and total' do
        expected_local_length   = 5
        expected_generic_length = 6
        total                   = expected_local_length + expected_generic_length

        pending_job_count_by_queue = {
          cc_local:   expected_local_length,
          cc_generic: expected_generic_length
        }

        updater.update_job_queue_length(pending_job_count_by_queue, total)

        metric = prom_client.metrics.find { |m| m.name == :cc_job_queue_length_cc_local }
        expect(metric.get).to eq 5

        metric = prom_client.metrics.find { |m| m.name == :cc_job_queue_length_cc_generic }
        expect(metric.get).to eq 6

        metric = prom_client.metrics.find { |m| m.name == :cc_job_queue_length_total }
        expect(metric.get).to eq 11
      end
    end

    describe '#update_failed_job_count' do
      it 'records the number of failed jobs in the delayed job queue and the total to statsd' do
        expected_local_length   = 5
        expected_generic_length = 6
        total                   = expected_local_length + expected_generic_length

        failed_jobs_by_queue = {
          cc_local:   expected_local_length,
          cc_generic: expected_generic_length
        }

        updater.update_failed_job_count(failed_jobs_by_queue, total)

        metric = prom_client.metrics.find { |m| m.name == :cc_failed_job_count_cc_local }
        expect(metric.get).to eq 5

        metric = prom_client.metrics.find { |m| m.name == :cc_failed_job_count_cc_generic }
        expect(metric.get).to eq 6

        metric = prom_client.metrics.find { |m| m.name == :cc_failed_job_count_total }
        expect(metric.get).to eq 11
      end
    end

    describe '#update_thread_info' do
      it 'should contain EventMachine data' do
        thread_info = {
          thread_count:  5,
          event_machine: {
            connection_count: 10,
            threadqueue:      {
              size:        19,
              num_waiting: 2,
            },
            resultqueue: {
              size:        8,
              num_waiting: 1,
            },
          },
        }

        updater.update_thread_info(thread_info)

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
          uptime:         33,
          cpu_load_avg:   0.5,
          mem_used_bytes: 542,
          mem_free_bytes: 927,
          mem_bytes:      1,
          cpu:            2.0,
          num_cores:      4,
        }

        updater.update_vitals(vitals)

        metric = prom_client.metrics.find { |m| m.name == :cc_vitals_uptime }
        expect(metric.get).to eq 33

        metric = prom_client.metrics.find { |m| m.name == :cc_vitals_cpu_load_avg }
        expect(metric.get).to eq 0.5

        metric = prom_client.metrics.find { |m| m.name == :cc_vitals_mem_used_bytes }
        expect(metric.get).to eq 542

        metric = prom_client.metrics.find { |m| m.name == :cc_vitals_mem_free_bytes }
        expect(metric.get).to eq 927

        metric = prom_client.metrics.find { |m| m.name == :cc_vitals_mem_bytes }
        expect(metric.get).to eq 1

        metric = prom_client.metrics.find { |m| m.name == :cc_vitals_cpu }
        expect(metric.get).to eq 2.0

        metric = prom_client.metrics.find { |m| m.name == :cc_vitals_num_cores }
        expect(metric.get).to eq 4
      end
    end

    describe '#update_log_counts' do
      it 'updates log counts' do
        counts = {
          off:    1,
          fatal:  2,
          error:  3,
          warn:   4,
          info:   5,
          debug:  6,
          debug1: 7,
          debug2: 8,
          all:    9
        }

        updater.update_log_counts(counts)

        metric = prom_client.metrics.find { |m| m.name == :cc_log_count_off }
        expect(metric.get).to eq 1

        metric = prom_client.metrics.find { |m| m.name == :cc_log_count_fatal }
        expect(metric.get).to eq 2

        metric = prom_client.metrics.find { |m| m.name == :cc_log_count_error }
        expect(metric.get).to eq 3

        metric = prom_client.metrics.find { |m| m.name == :cc_log_count_warn }
        expect(metric.get).to eq 4

        metric = prom_client.metrics.find { |m| m.name == :cc_log_count_info }
        expect(metric.get).to eq 5

        metric = prom_client.metrics.find { |m| m.name == :cc_log_count_debug }
        expect(metric.get).to eq 6

        metric = prom_client.metrics.find { |m| m.name == :cc_log_count_debug1 }
        expect(metric.get).to eq 7

        metric = prom_client.metrics.find { |m| m.name == :cc_log_count_debug2 }
        expect(metric.get).to eq 8

        metric = prom_client.metrics.find { |m| m.name == :cc_log_count_all }
        expect(metric.get).to eq 9
      end
    end

    describe '#update_task_stats' do
      it 'records the number of running tasks and task memory' do
        updater.update_task_stats(5, 512)

        metric = prom_client.metrics.find { |m| m.name == :cc_tasks_running_count }
        expect(metric.get).to eq 5

        metric = prom_client.metrics.find { |m| m.name == :cc_tasks_running_memory_in_mb }
        expect(metric.get).to eq 512
      end
    end

    describe '#update_synced_invalid_lrps' do
      it 'records number of running tasks and task memory to statsd' do
        updater.update_synced_invalid_lrps(5)
        metric = prom_client.metrics.find { |m| m.name == :cc_diego_sync_invalid_desired_lrps }
        expect(metric.get).to eq 5
      end
    end

    describe '#start_staging_request_received' do
      it 'increments "cc_staging_requested"' do
        updater.start_staging_request_received

        metric = prom_client.metrics.find { |m| m.name == :cc_staging_requested }
        expect(metric.get).to eq 1

        updater.start_staging_request_received

        metric = prom_client.metrics.find { |m| m.name == :cc_staging_requested }
        expect(metric.get).to eq 2
      end
    end

    describe '#report_staging_success_metrics' do
      it 'records staging success metrics' do
        duration_ns = 20 * 1e9

        updater.report_staging_success_metrics(duration_ns)
        metric = prom_client.metrics.find { |m| m.name == :cc_staging_succeeded }
        expect(metric.get).to eq 1

        metric = prom_client.metrics.find { |m| m.name == :cc_staging_succeeded_duration }
        # expected buckets for duration, in millis : 10000, 15000, 20000, 25000, 30000
        expect(metric.get).to eq({ '10000.0' => 0, '15000.0' => 0, '20000.0' => 1, '25000.0' => 1, '30000.0' => 1, 'sum' => 20000, '+Inf' => 1 })
      end
    end

    describe '#report_staging_failure_metrics' do
      it 'emits staging failure metrics' do
        duration_ns = 20 * 1e9

        updater.report_staging_failure_metrics(duration_ns)
        metric = prom_client.metrics.find { |m| m.name == :cc_staging_failed }
        expect(metric.get).to eq 1

        metric = prom_client.metrics.find { |m| m.name == :cc_staging_failed_duration }
        # expected buckets for duration, in millis : 10000, 15000, 20000, 25000, 30000
        expect(metric.get).to eq({ '10000.0' => 0, '15000.0' => 0, '20000.0' => 1, '25000.0' => 1, '30000.0' => 1, 'sum' => 20000, '+Inf' => 1 })
      end
    end

    describe '#report_diego_cell_sync_duration' do
      it 'reports diego cell sync duration' do
        duration_ns = 20 * 1e9

        updater.report_diego_cell_sync_duration(duration_ns)
        metric = prom_client.metrics.find { |m| m.name == :cc_diego_sync_duration }
        expect(metric.get).to eq({ 'count' => 1.0, 'sum' => 20000000000.0 })

        metric = prom_client.metrics.find { |m| m.name == :cc_diego_sync_duration_gauge }
        expect(metric.get).to eq duration_ns
      end
    end

    describe '#report_deployment_duration' do
      it 'reports deployments update duration' do
        duration_ns = 20 * 1e9

        updater.report_deployment_duration(duration_ns)
        metric = prom_client.metrics.find { |m| m.name == :cc_deployments_update_duration }
        expect(metric.get).to eq({ 'count' => 1.0, 'sum' => 20000000000.0 })

        metric = prom_client.metrics.find { |m| m.name == :cc_deployments_update_duration_gauge }
        expect(metric.get).to eq duration_ns
      end
    end
  end
end
