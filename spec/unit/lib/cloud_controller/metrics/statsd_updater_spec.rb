require 'spec_helper'
require 'cloud_controller/metrics/statsd_updater'

module VCAP::CloudController::Metrics
  describe StatsdUpdater do
    let(:updater) { StatsdUpdater.new(statsd_client) }
    let(:statsd_client) { Statsd.new('localhost', 9999) }

    describe '#record_user_count' do
      before do
        allow(statsd_client).to receive(:gauge)
      end

      it 'emits number of users to statsd' do
        expected_user_count = 5

        updater.record_user_count(expected_user_count)

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
          cc_local:   expected_local_length,
          cc_generic: expected_generic_length
        }

        updater.update_job_queue_length(pending_job_count_by_queue, total)

        expect(batch).to have_received(:gauge).with('cc.job_queue_length.cc_local', expected_local_length)
        expect(batch).to have_received(:gauge).with('cc.job_queue_length.cc_generic', expected_generic_length)
        expect(batch).to have_received(:gauge).with('cc.job_queue_length.total', total)
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
          cc_local:   expected_local_length,
          cc_generic: expected_generic_length
        }

        updater.update_failed_job_count(failed_jobs_by_queue, total)

        expect(batch).to have_received(:gauge).with('cc.failed_job_count.cc_local', expected_local_length)
        expect(batch).to have_received(:gauge).with('cc.failed_job_count.cc_generic', expected_generic_length)
        expect(batch).to have_received(:gauge).with('cc.failed_job_count.total', total)
      end
    end

    describe '#update_thread_info' do
      let(:batch) { double(:batch) }

      before do
        allow(statsd_client).to receive(:batch).and_yield(batch)
        allow(batch).to receive(:gauge)
      end

      it 'should contain EventMachine data' do
        thread_info = {
          thread_count:  5,
          event_machine: {
            connection_count: 10,
            threadqueue:      {
              size:        19,
              num_waiting: 2,
            },
            resultqueue:      {
              size:        8,
              num_waiting: 1,
            },
          },
        }

        updater.update_thread_info(thread_info)

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
          uptime:         33,
          cpu_load_avg:   0.5,
          mem_used_bytes: 542,
          mem_free_bytes: 927,
          mem_bytes:      1,
          cpu:            2.0,
          num_cores:      4,
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
  end
end
