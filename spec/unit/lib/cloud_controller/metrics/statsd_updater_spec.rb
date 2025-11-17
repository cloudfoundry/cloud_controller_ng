require 'spec_helper'
require 'cloud_controller/metrics/statsd_updater'

module VCAP::CloudController::Metrics
  RSpec.describe StatsdUpdater do
    let(:updater) { StatsdUpdater.new(statsd_client) }
    let(:statsd_client) { Statsd.new('localhost', 9999) }
    let(:store) { double(:store) }

    describe '#update_deploying_count' do
      before do
        allow(statsd_client).to receive(:gauge)
      end

      it 'emits the current number of deployments that are DEPLOYING to statsd' do
        expected_deploying_count = 7

        updater.update_deploying_count(expected_deploying_count)

        expect(statsd_client).to have_received(:gauge).with('cc.deployments.deploying', expected_deploying_count)
      end
    end

    describe '#update_user_count' do
      before do
        allow(statsd_client).to receive(:gauge)
      end

      it 'emits number of users to statsd' do
        expected_user_count = 5

        updater.update_user_count(expected_user_count)

        expect(statsd_client).to have_received(:gauge).with('cc.total_users', expected_user_count)
      end
    end

    describe '#update_job_queue_length' do
      let(:batch) { double(:batch) }

      before do
        allow(statsd_client).to receive(:batch).and_yield(batch)
        allow(batch).to receive(:gauge)
      end

      it 'emits the length of the delayed job queues and total to statsd' do
        expected_local_length   = 5
        expected_generic_length = 6
        total                   = expected_local_length + expected_generic_length

        pending_job_count_by_queue = {
          cc_local: expected_local_length,
          cc_generic: expected_generic_length
        }

        updater.update_job_queue_length(pending_job_count_by_queue, total)

        expect(batch).to have_received(:gauge).with('cc.job_queue_length.cc_local', expected_local_length)
        expect(batch).to have_received(:gauge).with('cc.job_queue_length.cc_generic', expected_generic_length)
        expect(batch).to have_received(:gauge).with('cc.job_queue_length.total', total)
      end
    end

    describe '#update_job_queue_load' do
      let(:batch) { double(:batch) }

      before do
        allow(statsd_client).to receive(:batch).and_yield(batch)
        allow(batch).to receive(:gauge)
      end

      it 'emits the load of the delayed job queues and total to statsd' do
        expected_local_load   = 5
        expected_generic_load = 6
        total                   = expected_local_load + expected_generic_load

        pending_job_load_by_queue = {
          cc_local: expected_local_load,
          cc_generic: expected_generic_load
        }

        updater.update_job_queue_load(pending_job_load_by_queue, total)

        expect(batch).to have_received(:gauge).with('cc.job_queue_load.cc_local', expected_local_load)
        expect(batch).to have_received(:gauge).with('cc.job_queue_load.cc_generic', expected_generic_load)
        expect(batch).to have_received(:gauge).with('cc.job_queue_load.total', total)
      end
    end

    describe '#update_failed_job_count' do
      let(:batch) { double(:batch) }

      before do
        allow(statsd_client).to receive(:batch).and_yield(batch)
        allow(batch).to receive(:gauge)
      end

      it 'emits the number of failed jobs in the delayed job queue and the total to statsd' do
        expected_local_length   = 5
        expected_generic_length = 6
        total                   = expected_local_length + expected_generic_length

        failed_jobs_by_queue = {
          cc_local: expected_local_length,
          cc_generic: expected_generic_length
        }

        updater.update_failed_job_count(failed_jobs_by_queue, total)

        expect(batch).to have_received(:gauge).with('cc.failed_job_count.cc_local', expected_local_length)
        expect(batch).to have_received(:gauge).with('cc.failed_job_count.cc_generic', expected_generic_length)
        expect(batch).to have_received(:gauge).with('cc.failed_job_count.total', total)
      end
    end

    describe '#update_thread_info_thin' do
      let(:batch) { double(:batch) }

      before do
        allow(statsd_client).to receive(:batch).and_yield(batch)
        allow(batch).to receive(:gauge)
      end

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

        expect(batch).to have_received(:gauge).with('cc.thread_info.thread_count', 5)
        expect(batch).to have_received(:gauge).with('cc.thread_info.event_machine.connection_count', 10)
        expect(batch).to have_received(:gauge).with('cc.thread_info.event_machine.threadqueue.size', 19)
        expect(batch).to have_received(:gauge).with('cc.thread_info.event_machine.threadqueue.num_waiting', 2)
        expect(batch).to have_received(:gauge).with('cc.thread_info.event_machine.resultqueue.size', 8)
        expect(batch).to have_received(:gauge).with('cc.thread_info.event_machine.resultqueue.num_waiting', 1)
      end
    end

    describe '#update_vitals' do
      let(:batch) { double(:batch) }

      before do
        allow(statsd_client).to receive(:batch).and_yield(batch)
        allow(batch).to receive(:gauge)
      end

      it 'sends vitals to statsd' do
        vitals = {
          uptime: 33,
          cpu_load_avg: 0.5,
          mem_used_bytes: 542,
          mem_free_bytes: 927,
          mem_bytes: 1,
          cpu: 2.0,
          num_cores: 4
        }

        updater.update_vitals(vitals)

        expect(batch).to have_received(:gauge).with('cc.vitals.uptime', 33)
        expect(batch).to have_received(:gauge).with('cc.vitals.cpu_load_avg', 0.5)
        expect(batch).to have_received(:gauge).with('cc.vitals.mem_used_bytes', 542)
        expect(batch).to have_received(:gauge).with('cc.vitals.mem_free_bytes', 927)
        expect(batch).to have_received(:gauge).with('cc.vitals.mem_bytes', 1)
        expect(batch).to have_received(:gauge).with('cc.vitals.cpu', 2.0)
        expect(batch).to have_received(:gauge).with('cc.vitals.num_cores', 4)
      end
    end

    describe '#update_log_counts' do
      let(:batch) { double(:batch) }

      before do
        allow(statsd_client).to receive(:batch).and_yield(batch)
        allow(batch).to receive(:gauge)
      end

      it 'sends log counts to statsd' do
        counts = {
          off: 1,
          fatal: 2,
          error: 3,
          warn: 4,
          info: 5,
          debug: 6,
          debug1: 7,
          debug2: 8,
          all: 9
        }

        updater.update_log_counts(counts)

        expect(batch).to have_received(:gauge).with('cc.log_count.off', 1)
        expect(batch).to have_received(:gauge).with('cc.log_count.fatal', 2)
        expect(batch).to have_received(:gauge).with('cc.log_count.error', 3)
        expect(batch).to have_received(:gauge).with('cc.log_count.warn', 4)
        expect(batch).to have_received(:gauge).with('cc.log_count.info', 5)
        expect(batch).to have_received(:gauge).with('cc.log_count.debug', 6)
        expect(batch).to have_received(:gauge).with('cc.log_count.debug1', 7)
        expect(batch).to have_received(:gauge).with('cc.log_count.debug2', 8)
        expect(batch).to have_received(:gauge).with('cc.log_count.all', 9)
      end
    end

    describe '#update_task_stats' do
      let(:batch) { instance_double(Statsd::Batch, gauge: nil) }

      before do
        allow(statsd_client).to receive(:batch).and_yield(batch)
      end

      it 'emits number of running tasks and task memory to statsd' do
        updater.update_task_stats(5, 512)

        expect(batch).to have_received(:gauge).with('cc.tasks_running.count', 5)
        expect(batch).to have_received(:gauge).with('cc.tasks_running.memory_in_mb', 512)
      end
    end

    describe '#update_synced_invalid_lrps' do
      before do
        allow(statsd_client).to receive(:gauge)
      end

      it 'emits number of running tasks and task memory to statsd' do
        updater.update_synced_invalid_lrps(5)
        expect(statsd_client).to have_received(:gauge).with('cc.diego_sync.invalid_desired_lrps', 5)
      end
    end

    describe '#start_staging_request_received' do
      before do
        allow(statsd_client).to receive(:increment)
      end

      it 'increments "cc.staging.requested"' do
        updater.start_staging_request_received
        expect(statsd_client).to have_received(:increment).with('cc.staging.requested')
      end
    end

    describe '#report_staging_success_metrics' do
      before do
        allow(statsd_client).to receive(:increment)
        allow(statsd_client).to receive(:timing)
      end

      it 'emits staging success metrics' do
        duration_ns = 10 * 1e9
        duration_ms = (duration_ns / 1e6).to_i

        updater.report_staging_success_metrics(duration_ns)
        expect(statsd_client).to have_received(:increment).with('cc.staging.succeeded')
        expect(statsd_client).to have_received(:timing).with('cc.staging.succeeded_duration', duration_ms)
      end
    end

    describe '#report_staging_failure_metrics' do
      before do
        allow(statsd_client).to receive(:increment)
        allow(statsd_client).to receive(:timing)
      end

      it 'emits staging failure metrics' do
        duration_ns = 10 * 1e9
        duration_ms = (duration_ns / 1e6).to_i

        updater.report_staging_failure_metrics(duration_ns)
        expect(statsd_client).to have_received(:increment).with('cc.staging.failed')
        expect(statsd_client).to have_received(:timing).with('cc.staging.failed_duration', duration_ms)
      end
    end

    describe '#start_request' do
      before do
        allow(statsd_client).to receive(:increment)
        allow(statsd_client).to receive(:gauge)
        allow(updater).to receive(:store).and_return(store)
        allow(store).to receive(:increment_request_outstanding_gauge).and_return(4)
      end

      it 'increments outstanding requests for statsd' do
        updater.start_request

        expect(store).to have_received(:increment_request_outstanding_gauge)
        expect(statsd_client).to have_received(:gauge).with('cc.requests.outstanding.gauge', 4)
        expect(statsd_client).to have_received(:increment).with('cc.requests.outstanding')
      end
    end

    describe '#complete_request' do
      let(:batch) { double(:batch) }
      let(:status) { 204 }

      before do
        allow(statsd_client).to receive(:batch).and_yield(batch)
        allow(statsd_client).to receive(:gauge)
        allow(batch).to receive(:increment)
        allow(batch).to receive(:decrement)
        allow(updater).to receive(:store).and_return(store)
        allow(store).to receive(:decrement_request_outstanding_gauge).and_return(5)
      end

      it 'increments completed, decrements outstanding, increments status for statsd' do
        updater.complete_request(status)

        expect(store).to have_received(:decrement_request_outstanding_gauge)
        expect(statsd_client).to have_received(:gauge).with('cc.requests.outstanding.gauge', 5)
        expect(batch).to have_received(:decrement).with('cc.requests.outstanding')
        expect(batch).to have_received(:increment).with('cc.requests.completed')
        expect(batch).to have_received(:increment).with('cc.http_status.2XX')
      end

      it 'normalizes http status codes in statsd' do
        updater.complete_request(200)
        expect(batch).to have_received(:increment).with('cc.http_status.2XX')

        updater.complete_request(300)
        expect(batch).to have_received(:increment).with('cc.http_status.3XX')

        updater.complete_request(400)
        expect(batch).to have_received(:increment).with('cc.http_status.4XX')
      end
    end

    describe '#store' do
      let(:config) { double(:config) }

      before do
        allow(config).to receive(:get).with(:cc, :enable_statsd_metrics).and_return(true)
        allow(VCAP::CloudController::Config).to receive(:config).and_return(config)
      end

      context 'when redis socket is not configured' do
        before do
          allow(config).to receive(:get).with(:redis, :socket).and_return(nil)
        end

        it 'returns an instance of InMemoryStore' do
          store = updater.send(:store)
          expect(store).to be_an_instance_of(StatsdUpdater::InMemoryStore)
        end
      end

      context 'when redis socket is configured' do
        let(:redis_socket) { 'redis.sock' }

        before do
          allow(config).to receive(:get).with(:redis, :socket).and_return(redis_socket)
          allow(config).to receive(:get).with(:puma, :max_threads).and_return(nil)
        end

        it 'returns an instance of RedisStore' do
          expect(ConnectionPool::Wrapper).to receive(:new).with(size: 1).and_call_original
          store = updater.send(:store)
          expect(store).to be_an_instance_of(StatsdUpdater::RedisStore)
        end

        context 'when puma max threads is set' do
          let(:pool_size) { 10 }

          before do
            allow(config).to receive(:get).with(:puma, :max_threads).and_return(pool_size)
          end

          it 'passes the connection pool size to RedisStore' do
            expect(ConnectionPool::Wrapper).to receive(:new).with(size: pool_size).and_call_original
            updater.send(:store)
          end
        end
      end
    end

    describe StatsdUpdater::InMemoryStore do
      let(:store) { StatsdUpdater::InMemoryStore.new }

      it 'increments the counter' do
        expect(store.increment_request_outstanding_gauge).to eq(1)
        expect(store.increment_request_outstanding_gauge).to eq(2)
        expect(store.increment_request_outstanding_gauge).to eq(3)
      end

      it 'decrements the counter' do
        expect(store.decrement_request_outstanding_gauge).to eq(-1)
        expect(store.decrement_request_outstanding_gauge).to eq(-2)
        expect(store.decrement_request_outstanding_gauge).to eq(-3)
      end
    end

    describe StatsdUpdater::RedisStore do
      let(:redis_socket) { 'redis.sock' }
      let(:connection_pool_size) { 5 }
      let(:redis_store) { StatsdUpdater::RedisStore.new(redis_socket, connection_pool_size) }
      let(:redis) { instance_double(Redis) }
      let(:config) { double(:config) }

      before do
        allow(VCAP::CloudController::Config).to receive(:config).and_return(config)
        allow(ConnectionPool::Wrapper).to receive(:new).and_return(redis)
        allow(redis).to receive(:set)
      end

      describe 'initialization' do
        it 'clears cc.requests.outstanding.gauge' do
          expect(redis).to receive(:set).with('metrics:cc.requests.outstanding.gauge', 0)
          StatsdUpdater::RedisStore.new(redis_socket, connection_pool_size)
        end

        it 'configures a Redis connection pool with specified size' do
          expect(ConnectionPool::Wrapper).to receive(:new).with(size: connection_pool_size).and_call_original
          StatsdUpdater::RedisStore.new(redis_socket, connection_pool_size)
        end

        context 'when the connection pool size is not provided' do
          before do
            allow(config).to receive(:get).with(:puma, :max_threads).and_return(nil)
          end

          it 'uses a default connection pool size of 1' do
            expect(ConnectionPool::Wrapper).to receive(:new).with(size: 1).and_call_original
            StatsdUpdater::RedisStore.new(redis_socket, nil)
          end

          context 'when puma max threads is set' do
            before do
              allow(config).to receive(:get).with(:puma, :max_threads).and_return(10)
            end

            it 'uses puma max threads' do
              expect(ConnectionPool::Wrapper).to receive(:new).with(size: 10).and_call_original
              StatsdUpdater::RedisStore.new(redis_socket, nil)
            end
          end
        end
      end

      it 'increments the gauge in Redis' do
        allow(redis).to receive(:incr).with('metrics:cc.requests.outstanding.gauge').and_return(1)
        expect(redis_store.increment_request_outstanding_gauge).to eq(1)
      end

      it 'decrements the gauge in Redis' do
        allow(redis).to receive(:decr).with('metrics:cc.requests.outstanding.gauge').and_return(-1)
        expect(redis_store.decrement_request_outstanding_gauge).to eq(-1)
      end
    end
  end
end
