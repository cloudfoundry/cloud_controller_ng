require 'spec_helper'
require 'cloud_controller/metrics/periodic_updater'

module VCAP::CloudController::Metrics
  RSpec.describe PeriodicUpdater do
    let(:periodic_updater) { PeriodicUpdater.new(start_time, log_counter, [updater1, updater2]) }
    let(:updater1) { double(:updater1) }
    let(:updater2) { double(:updater2) }
    let(:threadqueue) { double(EventMachine::Queue, size: 20, num_waiting: 0) }
    let(:resultqueue) { double(EventMachine::Queue, size: 0, num_waiting: 1) }
    let(:start_time) { Time.now.utc - 90 }
    let(:log_counter) { double(:log_counter, counts: {}) }

    before do
      allow(EventMachine).to receive(:connection_count).and_return(123)

      allow(EventMachine).to receive(:instance_variable_get) do |instance_var|
        case instance_var
        when :@threadqueue then
          threadqueue
        when :@resultqueue then
          resultqueue
        else
          raise "Unexpected call: #{instance_var}"
        end
      end
    end

    describe 'task stats' do
      before do
        allow(updater1).to receive(:update_task_stats)
        allow(updater2).to receive(:update_task_stats)
      end

      describe 'number of tasks' do
        it 'should update the number of running tasks' do
          VCAP::CloudController::TaskModel.make(state: VCAP::CloudController::TaskModel::RUNNING_STATE)
          VCAP::CloudController::TaskModel::TASK_STATES.each do |state|
            VCAP::CloudController::TaskModel.make(state: state)
          end

          periodic_updater.update_task_stats

          expect(updater1).to have_received(:update_task_stats).with(2, anything)
          expect(updater2).to have_received(:update_task_stats).with(2, anything)
        end
      end

      it 'should update the total memory allocated to tasks' do
        VCAP::CloudController::TaskModel.make(state: VCAP::CloudController::TaskModel::RUNNING_STATE, memory_in_mb: 512)
        VCAP::CloudController::TaskModel::TASK_STATES.each do |state|
          VCAP::CloudController::TaskModel.make(state: state, memory_in_mb: 1)
        end

        periodic_updater.update_task_stats

        expect(updater1).to have_received(:update_task_stats).with(anything, 513)
        expect(updater2).to have_received(:update_task_stats).with(anything, 513)
      end

      context 'when there are no running tasks' do
        it 'properly reports 0' do
          periodic_updater.update_task_stats
          expect(updater1).to have_received(:update_task_stats).with(0, 0)
          expect(updater2).to have_received(:update_task_stats).with(0, 0)
        end
      end
    end

    describe '#setup_updates' do
      before do
        allow(updater1).to receive(:record_user_count)
        allow(updater1).to receive(:update_job_queue_length)
        allow(updater1).to receive(:update_thread_info)
        allow(updater1).to receive(:update_failed_job_count)
        allow(updater1).to receive(:update_vitals)
        allow(updater1).to receive(:update_log_counts)
        allow(updater1).to receive(:update_task_stats)

        allow(updater2).to receive(:record_user_count)
        allow(updater2).to receive(:update_job_queue_length)
        allow(updater2).to receive(:update_thread_info)
        allow(updater2).to receive(:update_failed_job_count)
        allow(updater2).to receive(:update_vitals)
        allow(updater2).to receive(:update_log_counts)
        allow(updater2).to receive(:update_task_stats)

        allow(EventMachine).to receive(:add_periodic_timer)
      end

      it 'bumps the number of users and sets periodic timer' do
        expect(periodic_updater).to receive(:record_user_count).once
        periodic_updater.setup_updates
      end

      it 'bumps the length of cc job queues and sets periodic timer' do
        expect(periodic_updater).to receive(:update_job_queue_length).once
        periodic_updater.setup_updates
      end

      it 'bumps the length of cc failed job queues and sets periodic timer' do
        expect(periodic_updater).to receive(:update_failed_job_count).once
        periodic_updater.setup_updates
      end

      it 'updates thread count and event machine queues' do
        expect(periodic_updater).to receive(:update_thread_info).once
        periodic_updater.setup_updates
      end

      it 'updates the vitals' do
        expect(periodic_updater).to receive(:update_vitals).once
        periodic_updater.setup_updates
      end

      it 'updates the log counts' do
        expect(periodic_updater).to receive(:update_log_counts).once
        periodic_updater.setup_updates
      end

      it 'updates the task stats' do
        expect(periodic_updater).to receive(:update_task_stats).once
        periodic_updater.setup_updates
      end

      context 'when EventMachine periodic_timer tasks are run' do
        before do
          @periodic_timers = []

          allow(EventMachine).to receive(:add_periodic_timer) do |interval, &block|
            @periodic_timers << {
              interval: interval,
              block:    block
            }
          end

          periodic_updater.setup_updates
        end

        it 'bumps the number of users and sets periodic timer' do
          expect(periodic_updater).to receive(:record_user_count).once
          expect(@periodic_timers[0][:interval]).to eq(600)

          @periodic_timers[0][:block].call
        end

        it 'bumps the length of cc job queues and sets periodic timer' do
          expect(periodic_updater).to receive(:update_job_queue_length).once
          expect(@periodic_timers[1][:interval]).to eq(30)

          @periodic_timers[1][:block].call
        end

        it 'updates thread count and event machine queues' do
          expect(periodic_updater).to receive(:update_thread_info).once
          expect(@periodic_timers[2][:interval]).to eq(30)

          @periodic_timers[2][:block].call
        end

        it 'bumps the length of cc failed job queues and sets periodic timer' do
          expect(periodic_updater).to receive(:update_failed_job_count).once
          expect(@periodic_timers[3][:interval]).to eq(30)

          @periodic_timers[3][:block].call
        end

        it 'updates the vitals' do
          expect(periodic_updater).to receive(:update_vitals).once
          expect(@periodic_timers[4][:interval]).to eq(30)

          @periodic_timers[4][:block].call
        end

        it 'updates the log counts' do
          expect(periodic_updater).to receive(:update_log_counts).once
          expect(@periodic_timers[5][:interval]).to eq(30)

          @periodic_timers[5][:block].call
        end

        it 'updates the task stats' do
          expect(periodic_updater).to receive(:update_task_stats).once
          expect(@periodic_timers[6][:interval]).to eq(30)

          @periodic_timers[6][:block].call
        end
      end
    end

    describe '#record_user_count' do
      before do
        allow(updater1).to receive(:record_user_count)
        allow(updater2).to receive(:record_user_count)
      end

      it 'should include the number of users in varz' do
        4.times { VCAP::CloudController::User.create(guid: SecureRandom.uuid) }

        periodic_updater.record_user_count

        expect(updater1).to have_received(:record_user_count).with(VCAP::CloudController::User.count)
        expect(updater2).to have_received(:record_user_count).with(VCAP::CloudController::User.count)
      end
    end

    describe '#update_job_queue_length' do
      before do
        allow(updater1).to receive(:update_job_queue_length)
        allow(updater2).to receive(:update_job_queue_length)
      end

      it 'should include the length of the delayed job queue and the total' do
        Delayed::Job.enqueue(VCAP::CloudController::Jobs::Runtime::AppBitsPacker.new('abc', 'def', []), queue: 'cc_local')
        Delayed::Job.enqueue(VCAP::CloudController::Jobs::Runtime::AppBitsPacker.new('ghj', 'klm', []), queue: 'cc_local')
        Delayed::Job.enqueue(VCAP::CloudController::Jobs::Runtime::AppBitsPacker.new('abc', 'def', []), queue: 'cc_generic')

        periodic_updater.update_job_queue_length

        expected_pending_job_count_by_queue = {
          cc_local:   2,
          cc_generic: 1
        }
        expected_total = 3

        expect(updater1).to have_received(:update_job_queue_length).with(expected_pending_job_count_by_queue, expected_total)
        expect(updater2).to have_received(:update_job_queue_length).with(expected_pending_job_count_by_queue, expected_total)
      end

      it 'should find jobs which have not been attempted yet' do
        Delayed::Job.enqueue(VCAP::CloudController::Jobs::Runtime::AppBitsPacker.new('abc', 'def', []), queue: 'cc_local')
        Delayed::Job.enqueue(VCAP::CloudController::Jobs::Runtime::AppBitsPacker.new('abc', 'def', []), queue: 'cc_generic')

        periodic_updater.update_job_queue_length

        expected_pending_job_count_by_queue = {
          cc_local:   1,
          cc_generic: 1
        }
        expected_total = 2

        expect(updater1).to have_received(:update_job_queue_length).with(expected_pending_job_count_by_queue, expected_total)
        expect(updater2).to have_received(:update_job_queue_length).with(expected_pending_job_count_by_queue, expected_total)
      end

      it 'should ignore jobs that have already been attempted' do
        job = VCAP::CloudController::Jobs::Runtime::AppBitsPacker.new('abc', 'def', [])
        Delayed::Job.enqueue(job, queue: 'cc_generic', attempts: 1)

        periodic_updater.update_job_queue_length

        expected_pending_job_count_by_queue = {}
        expected_total                      = 0

        expect(updater1).to have_received(:update_job_queue_length).with(expected_pending_job_count_by_queue, expected_total)
        expect(updater2).to have_received(:update_job_queue_length).with(expected_pending_job_count_by_queue, expected_total)
      end
    end

    describe '#update_failed_job_count' do
      before do
        allow(updater1).to receive(:update_failed_job_count)
        allow(updater2).to receive(:update_failed_job_count)
      end

      it 'includes the number of failed jobs in the delayed job queue with a total and sends it to all updaters' do
        Delayed::Job.enqueue(VCAP::CloudController::Jobs::Runtime::AppBitsPacker.new('abc', 'def', []), queue: 'cc_local')
        Delayed::Job.enqueue(VCAP::CloudController::Jobs::Runtime::AppBitsPacker.new('ghj', 'klm', []), queue: 'cc_local')
        Delayed::Job.enqueue(VCAP::CloudController::Jobs::Runtime::AppBitsPacker.new('abc', 'def', []), queue: 'cc_generic')
        Delayed::Job.dataset.update(failed_at: DateTime.now.utc)
        Delayed::Job.enqueue(VCAP::CloudController::Jobs::Runtime::AppBitsPacker.new('gej', 'kkm', []), queue: 'cc_local')
        Delayed::Job.enqueue(VCAP::CloudController::Jobs::Runtime::AppBitsPacker.new('bcz', 'dqf', []), queue: 'cc_generic')

        periodic_updater.update_failed_job_count

        expected_failed_jobs_by_queue = {
          cc_local:   2,
          cc_generic: 1
        }
        expected_total = 3

        expect(updater1).to have_received(:update_failed_job_count).with(expected_failed_jobs_by_queue, expected_total)
        expect(updater2).to have_received(:update_failed_job_count).with(expected_failed_jobs_by_queue, expected_total)
      end
    end

    describe '#update_thread_info' do
      before do
        allow(updater1).to receive(:update_thread_info)
        allow(updater2).to receive(:update_thread_info)

        periodic_updater.update_thread_info
      end

      it 'should contain EventMachine data and send it to all updaters' do
        expected_thread_info = {
          thread_count:  Thread.list.size,
          event_machine: {
            connection_count: 123,
            threadqueue:      {
              size:        20,
              num_waiting: 0,
            },
            resultqueue: {
              size:        0,
              num_waiting: 1,
            },
          },
        }

        expect(updater1).to have_received(:update_thread_info).with(expected_thread_info)
        expect(updater2).to have_received(:update_thread_info).with(expected_thread_info)
      end

      context 'when resultqueue and/or threadqueue is not a queue' do
        let(:resultqueue) { [] }
        let(:threadqueue) { nil }

        it 'does not blow up' do
          expected_thread_info = {
            thread_count:  Thread.list.size,
            event_machine: {
              connection_count: 123,
              threadqueue:      {
                size:        0,
                num_waiting: 0,
              },
              resultqueue: {
                size:        0,
                num_waiting: 0,
              },
            },
          }

          expect(updater1).to have_received(:update_thread_info).with(expected_thread_info)
          expect(updater2).to have_received(:update_thread_info).with(expected_thread_info)
        end
      end
    end

    describe '#update_vitals' do
      before do
        allow(updater1).to receive(:update_vitals)
        allow(updater2).to receive(:update_vitals)

        allow(VCAP::Stats).to receive(:process_memory_bytes_and_cpu).and_return([1.1, 2])
        allow(VCAP::Stats).to receive(:cpu_load_average).and_return(0.5)
        allow(VCAP::Stats).to receive(:memory_used_bytes).and_return(542)
        allow(VCAP::Stats).to receive(:memory_free_bytes).and_return(927)
        allow(VCAP).to receive(:num_cores).and_return(4)
      end

      it 'update the vitals on all updaters' do
        periodic_updater.update_vitals

        expect(updater1).to have_received(:update_vitals) do |expected_vitals|
          expect(expected_vitals[:uptime]).to be_within(1).of(Time.now.to_i - start_time.to_i)
          expect(expected_vitals[:cpu_load_avg]).to eq(0.5)
          expect(expected_vitals[:mem_used_bytes]).to eq(542)
          expect(expected_vitals[:mem_free_bytes]).to eq(927)
          expect(expected_vitals[:mem_bytes]).to eq(1.1.to_i)
          expect(expected_vitals[:cpu]).to eq(2.to_f)
          expect(expected_vitals[:num_cores]).to eq(4)
        end

        expect(updater2).to have_received(:update_vitals) do |expected_vitals|
          expect(expected_vitals[:uptime]).to be_within(1).of(Time.now.to_i - start_time.to_i)
          expect(expected_vitals[:cpu_load_avg]).to eq(0.5)
          expect(expected_vitals[:mem_used_bytes]).to eq(542)
          expect(expected_vitals[:mem_free_bytes]).to eq(927)
          expect(expected_vitals[:mem_bytes]).to eq(1.1.to_i)
          expect(expected_vitals[:cpu]).to eq(2.to_f)
          expect(expected_vitals[:num_cores]).to eq(4)
        end
      end
    end

    describe '#update_log_counts' do
      let(:expected) do
        {
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
      end

      let(:count) do
        {
          'off'    => 1,
          'fatal'  => 2,
          'error'  => 3,
          'warn'   => 4,
          'info'   => 5,
          'debug'  => 6,
          'debug1' => 7,
          'debug2' => 8,
          'all'    => 9
        }
      end

      before do
        allow(updater1).to receive(:update_log_counts)
        allow(updater2).to receive(:update_log_counts)

        allow(log_counter).to receive(:counts).and_return(count)
      end

      it 'update the log counts on all updaters' do
        periodic_updater.update_log_counts

        expect(updater1).to have_received(:update_log_counts).with(expected)
        expect(updater2).to have_received(:update_log_counts).with(expected)
      end

      it 'fills in zeros for levels without counts' do
        count.delete('info')
        expected[:info] = 0

        periodic_updater.update_log_counts

        expect(updater1).to have_received(:update_log_counts).with(expected)
        expect(updater2).to have_received(:update_log_counts).with(expected)
      end
    end

    describe '#update!' do
      before do
        allow(updater1).to receive(:record_user_count)
        allow(updater1).to receive(:update_job_queue_length)
        allow(updater1).to receive(:update_thread_info)
        allow(updater1).to receive(:update_failed_job_count)
        allow(updater1).to receive(:update_vitals)
        allow(updater1).to receive(:update_log_counts)
        allow(updater1).to receive(:update_task_stats)

        allow(updater2).to receive(:record_user_count)
        allow(updater2).to receive(:update_job_queue_length)
        allow(updater2).to receive(:update_thread_info)
        allow(updater2).to receive(:update_failed_job_count)
        allow(updater2).to receive(:update_vitals)
        allow(updater2).to receive(:update_log_counts)
        allow(updater2).to receive(:update_task_stats)
      end

      it 'calls all update methods' do
        expect(periodic_updater).to receive(:record_user_count).once
        expect(periodic_updater).to receive(:update_job_queue_length).once
        expect(periodic_updater).to receive(:update_thread_info).once
        expect(periodic_updater).to receive(:update_failed_job_count).once
        expect(periodic_updater).to receive(:update_vitals).once
        expect(periodic_updater).to receive(:update_log_counts).once
        expect(periodic_updater).to receive(:update_task_stats).once
        periodic_updater.update!
      end
    end
  end
end
