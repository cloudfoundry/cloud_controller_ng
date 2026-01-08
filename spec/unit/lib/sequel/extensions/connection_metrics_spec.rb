require 'spec_helper'
require 'cloud_controller/execution_context'

RSpec.describe 'Sequel::ConnectionMetrics' do
  let(:db_config) { DbConfig.new }
  # each test will have their own db connection pool. This helps to isolate the test from each other.
  let(:db) { VCAP::CloudController::DB.connect(db_config.config, db_config.db_logger) }
  let(:logs) { StringIO.new }
  let(:logger) { Logger.new(logs) }
  let(:prometheus_updater) { spy(VCAP::CloudController::Metrics::PrometheusUpdater) }
  let(:thread) { double('Thread') }

  after do
    db.disconnect
  end

  describe 'initialize' do
    context 'api process' do
      before do
        VCAP::CloudController::ExecutionContext::API_PUMA_WORKER.set_process_type_env
        db.loggers << logger
        db.sql_log_level = :info

        allow(thread).to receive(:alive?).and_return(true)

        db.pool.instance_variable_set(:@prometheus_updater, prometheus_updater)
      end

      it 'initializes the prometheus_updater and connection_info' do
        expect(db.pool.instance_variable_get(:@prometheus_updater)).to eq(prometheus_updater)
        expect(db.pool.instance_variable_get(:@connection_info)).to be_a(Hash)
      end
    end

    context 'cc-worker process' do
      before do
        VCAP::CloudController::ExecutionContext::CC_WORKER.set_process_type_env
        allow(VCAP::CloudController::Metrics::PrometheusUpdater).to receive(:new).and_return(VCAP::CloudController::Metrics::PrometheusUpdater.new)

        db.loggers << logger
        db.sql_log_level = :info

        allow(thread).to receive(:alive?).and_return(true)
      end

      it 'initializes the prometheus_updater and for cc-worker' do
        expect(VCAP::CloudController::Metrics::PrometheusUpdater).to have_received(:new)
      end
    end
  end

  describe 'methods' do
    before do
      VCAP::CloudController::ExecutionContext::API_PUMA_WORKER.set_process_type_env
      db.loggers << logger
      db.sql_log_level = :info

      allow(thread).to receive(:alive?).and_return(true)

      db.pool.instance_variable_set(:@prometheus_updater, prometheus_updater)
    end

    describe 'acquire' do
      context 'when acquire returns a connection' do
        it 'increments the acquired DB connections metric' do
          expect(prometheus_updater).to receive(:increment_gauge_metric).with(:cc_acquired_db_connections_total, labels: { process_type: 'puma_worker' })

          db.pool.send(:acquire, thread)
        end

        it 'stores the timestamp when the connection was acquired' do
          db.pool.send(:acquire, thread)
          expect(db.pool.instance_variable_get(:@connection_info)[thread]).to have_key(:acquired_at)
        end
      end

      context 'when the pool is exhausted and throws a PoolTimeout' do
        before do
          # actually acquire throws the exception, but when mocking like this the extension would also be mocked away
          allow(db.pool).to receive(:assign_connection).and_raise(Sequel::PoolTimeout)
        end

        it 'increments the connection pool timeouts metric and raises' do
          expect(prometheus_updater).to receive(:increment_gauge_metric).with(:cc_db_connection_pool_timeouts_total, labels: { process_type: 'puma_worker' })

          expect { db.pool.send(:acquire, thread) }.to raise_error(Sequel::PoolTimeout)
        end

        it 'emits the time the thread waited for the connection' do
          db.pool.instance_variable_set(:@connection_info, db.pool.instance_variable_get(:@connection_info).merge!({ thread => { waiting_since: Time.now - 60 } }))
          expect(prometheus_updater).to receive(:update_histogram_metric).with(:cc_db_connection_wait_duration_seconds, an_instance_of(ActiveSupport::Duration),
                                                                               labels: { process_type: 'puma_worker' })

          expect { db.pool.send(:acquire, thread) }.to raise_error(Sequel::PoolTimeout)
        end
      end
    end

    describe 'assign_connection' do
      context 'when assign_connection returns a connection' do
        it 'does not set the waiting_since timestamp' do
          db.pool.send(:assign_connection, thread)
          expect(db.pool.instance_variable_get(:@connection_info)[thread]).to be_nil
        end
      end

      context 'when assign_connection does not return a connection' do
        before do
          db.pool.instance_variable_set(:@max_size, 1)
          db.pool.send(:acquire, thread)
        end

        it 'stores the timestamp since when the thread is waiting for the connection' do
          waiting_since = nil
          Timecop.freeze do
            waiting_since = Time.now
            expect(db.pool.send(:assign_connection, thread)).to be_nil
          end
          expect(db.pool.instance_variable_get(:@connection_info)[thread][:waiting_since]).to eq(waiting_since)
        end
      end
    end

    describe 'make_new' do
      it 'sets the open db connection metric to the current size of the pool' do
        expect(prometheus_updater).to receive(:update_gauge_metric).with(:cc_open_db_connections_total, an_instance_of(Integer), labels: { process_type: 'puma_worker' })
        db.pool.send(:make_new, thread)
      end
    end

    describe 'disconnect_connection' do
      let(:conn) { db.pool.send(:acquire, thread) }

      it 'sets the open db connection metric to the current size of the pool' do
        expect(prometheus_updater).to receive(:update_gauge_metric).with(:cc_open_db_connections_total, an_instance_of(Integer), labels: { process_type: 'puma_worker' })
        db.pool.send(:disconnect_connection, conn)
      end
    end

    describe 'release' do
      before do
        db.pool.send(:acquire, thread)
      end

      it 'emits the db connection hold duration' do
        acquired_at = Time.now - 5
        db.pool.instance_variable_set(:@connection_info, db.pool.instance_variable_get(:@connection_info).merge!({ thread => { acquired_at: } }))

        Timecop.freeze do
          hold_duration = Time.now - acquired_at
          expect(prometheus_updater).to receive(:update_histogram_metric).with(:cc_db_connection_hold_duration_seconds, hold_duration, labels: { process_type: 'puma_worker' })
          db.pool.send(:release, thread)
        end
      end

      it 'decrements the acquired db connection metric' do
        expect(prometheus_updater).to receive(:decrement_gauge_metric).with(:cc_acquired_db_connections_total, labels: { process_type: 'puma_worker' })
        db.pool.send(:release, thread)
      end

      it 'deletes the connection info' do
        db.pool.send(:release, thread)
        expect(db.pool.instance_variable_get(:@connection_info)[:thread]).to be_nil
      end

      context 'when the acquired_at timestamp is missing' do
        before do
          db.pool.instance_variable_set(:@connection_info, {})
        end

        it 'does not crash' do
          db.pool.send(:release, thread)
        end
      end
    end
  end
end
