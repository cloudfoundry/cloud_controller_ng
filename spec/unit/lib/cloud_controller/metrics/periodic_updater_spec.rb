require 'spec_helper'
require 'cloud_controller/metrics/periodic_updater'

module VCAP::CloudController::Metrics
  RSpec.describe PeriodicUpdater do
    let(:periodic_updater) { PeriodicUpdater.new(start_time, log_counter, logger, statsd_updater, prometheus_updater) }
    let(:statsd_updater) { double(:statsd_updater) }
    let(:prometheus_updater) { double(:prometheus_updater) }
    let(:start_time) { Time.now.utc - 90 }
    let(:log_counter) { double(:log_counter, counts: {}) }
    let(:logger) { double(:logger) }
    let(:stats_hash) do
      {
        booted_workers: 2,
        worker_status: [
          { started_at: '2023-11-29T13:15:05Z', index: 0, pid: 123, last_status: { running: 1, backlog: 0, busy_threads: 0, pool_capacity: 1, requests_count: 9 } },
          { started_at: '2023-11-29T13:15:10Z', index: 1, pid: 234, last_status: { running: 2, backlog: 1, busy_threads: 1, pool_capacity: 2, requests_count: 10 } }
        ]
      }
    end

    before do
      allow(Puma).to receive(:stats_hash).and_return(stats_hash)
    end

    describe 'task stats' do
      before do
        allow(statsd_updater).to receive(:update_task_stats)
        allow(prometheus_updater).to receive(:update_task_stats)
      end

      describe 'number of tasks' do
        it 'updates the number of running tasks' do
          VCAP::CloudController::TaskModel.make(state: VCAP::CloudController::TaskModel::RUNNING_STATE)
          VCAP::CloudController::TaskModel::TASK_STATES.each do |state|
            VCAP::CloudController::TaskModel.make(state:)
          end

          periodic_updater.update_task_stats

          expect(statsd_updater).to have_received(:update_task_stats).with(2, anything)
          expect(prometheus_updater).to have_received(:update_task_stats).with(2, anything)
        end
      end

      it 'updates the total memory allocated to tasks' do
        VCAP::CloudController::TaskModel.make(state: VCAP::CloudController::TaskModel::RUNNING_STATE, memory_in_mb: 512)
        VCAP::CloudController::TaskModel::TASK_STATES.each do |state|
          VCAP::CloudController::TaskModel.make(state: state, memory_in_mb: 1)
        end

        periodic_updater.update_task_stats

        expect(statsd_updater).to have_received(:update_task_stats).with(anything, 513)
        expect(prometheus_updater).to have_received(:update_task_stats).with(anything, 537_919_488)
      end

      context 'when there are no running tasks' do
        it 'properly reports 0' do
          periodic_updater.update_task_stats
          expect(statsd_updater).to have_received(:update_task_stats).with(0, 0)
          expect(prometheus_updater).to have_received(:update_task_stats).with(0, 0)
        end
      end
    end

    describe '#setup_updates' do
      before do
        allow(statsd_updater).to receive(:update_user_count)
        allow(statsd_updater).to receive(:update_job_queue_length)
        allow(statsd_updater).to receive(:update_job_queue_load)
        allow(statsd_updater).to receive(:update_failed_job_count)
        allow(statsd_updater).to receive(:update_vitals)
        allow(statsd_updater).to receive(:update_log_counts)
        allow(statsd_updater).to receive(:update_task_stats)
        allow(statsd_updater).to receive(:update_deploying_count)

        allow(prometheus_updater).to receive(:update_user_count)
        allow(prometheus_updater).to receive(:update_job_queue_length)
        allow(prometheus_updater).to receive(:update_job_queue_load)
        allow(prometheus_updater).to receive(:update_failed_job_count)
        allow(prometheus_updater).to receive(:update_vitals)
        allow(prometheus_updater).to receive(:update_task_stats)
        allow(prometheus_updater).to receive(:update_deploying_count)
        allow(prometheus_updater).to receive(:update_webserver_stats_puma)
      end

      context 'when Concurrent::TimerTasks are run' do
        before do
          @periodic_timers = []

          allow(Concurrent::TimerTask).to receive(:new) do |opts, &block|
            @periodic_timers << {
              interval: opts[:execution_interval],
              type: opts[:interval_type],
              now: opts[:run_now],
              block: block
            }
            double('TimerTask', execute: nil)
          end

          periodic_updater.setup_updates
        end

        it 'bumps the number of users and sets periodic timer' do
          expect(periodic_updater).to receive(:catch_error).once.and_call_original
          expect(periodic_updater).to receive(:update_user_count).once
          expect(@periodic_timers[0][:interval]).to eq(600)
          expect(@periodic_timers[0][:type]).to eq(:fixed_rate)
          expect(@periodic_timers[0][:now]).to be(true)

          @periodic_timers[0][:block].call
        end

        it 'bumps the length of cc job queues and sets periodic timer' do
          expect(periodic_updater).to receive(:catch_error).once.and_call_original
          expect(periodic_updater).to receive(:update_job_queue_length).once
          expect(@periodic_timers[1][:interval]).to eq(30)
          expect(@periodic_timers[1][:type]).to eq(:fixed_rate)
          expect(@periodic_timers[1][:now]).to be(true)

          @periodic_timers[1][:block].call
        end

        it 'bumps the load of cc job queues and sets periodic timer' do
          expect(periodic_updater).to receive(:catch_error).once.and_call_original
          expect(periodic_updater).to receive(:update_job_queue_load).once
          expect(@periodic_timers[2][:interval]).to eq(30)
          expect(@periodic_timers[2][:type]).to eq(:fixed_rate)
          expect(@periodic_timers[2][:now]).to be(true)

          @periodic_timers[2][:block].call
        end

        it 'bumps the length of cc failed job queues and sets periodic timer' do
          expect(periodic_updater).to receive(:catch_error).once.and_call_original
          expect(periodic_updater).to receive(:update_failed_job_count).once
          expect(@periodic_timers[3][:interval]).to eq(30)
          expect(@periodic_timers[3][:type]).to eq(:fixed_rate)
          expect(@periodic_timers[3][:now]).to be(true)

          @periodic_timers[3][:block].call
        end

        it 'updates the vitals' do
          expect(periodic_updater).to receive(:catch_error).once.and_call_original
          expect(periodic_updater).to receive(:update_vitals).once
          expect(@periodic_timers[4][:interval]).to eq(30)
          expect(@periodic_timers[4][:type]).to eq(:fixed_rate)
          expect(@periodic_timers[4][:now]).to be(true)

          @periodic_timers[4][:block].call
        end

        it 'updates the log counts' do
          expect(periodic_updater).to receive(:catch_error).once.and_call_original
          expect(periodic_updater).to receive(:update_log_counts).once
          expect(@periodic_timers[5][:interval]).to eq(30)
          expect(@periodic_timers[5][:type]).to eq(:fixed_rate)
          expect(@periodic_timers[5][:now]).to be(true)

          @periodic_timers[5][:block].call
        end

        it 'updates the task stats' do
          expect(periodic_updater).to receive(:catch_error).once.and_call_original
          expect(periodic_updater).to receive(:update_task_stats).once
          expect(@periodic_timers[6][:interval]).to eq(30)
          expect(@periodic_timers[6][:type]).to eq(:fixed_rate)
          expect(@periodic_timers[6][:now]).to be(true)

          @periodic_timers[6][:block].call
        end

        it 'updates the deploying count' do
          expect(periodic_updater).to receive(:catch_error).once.and_call_original
          expect(periodic_updater).to receive(:update_deploying_count).once
          expect(@periodic_timers[7][:interval]).to eq(30)
          expect(@periodic_timers[7][:type]).to eq(:fixed_rate)
          expect(@periodic_timers[7][:now]).to be(true)

          @periodic_timers[7][:block].call
        end

        it 'updates the webserver stats' do
          expect(periodic_updater).to receive(:catch_error).once.and_call_original
          expect(periodic_updater).to receive(:update_webserver_stats).once
          expect(@periodic_timers[8][:interval]).to eq(30)
          expect(@periodic_timers[8][:type]).to eq(:fixed_rate)
          expect(@periodic_timers[8][:now]).to be(true)

          @periodic_timers[8][:block].call
        end
      end

      context 'when PeriodicUpdater is shut down' do
        it 'does nothing when updates have not been setup' do
          expect { periodic_updater.stop_updates }.not_to raise_error
        end

        context 'when Concurrent::TimerTasks are stopped' do
          let(:tasks) { [] }
          let(:wait_for_termination_response) { nil }

          before do
            allow(Concurrent::TimerTask).to receive(:new) do |*|
              dbl = double('TimerTask', execute: nil, kill: nil, wait_for_termination: wait_for_termination_response)
              tasks << dbl
              dbl
            end

            periodic_updater.setup_updates
          end

          context 'when tasks are terminated in time' do
            let(:wait_for_termination_response) { true }

            it 'stops all tasks and returns true' do
              expect(tasks.size).to eq(9)
              expect(tasks).to all(receive(:kill).once)
              expect(tasks).to all(receive(:wait_for_termination).with(1).once)

              expect(periodic_updater.stop_updates).to be(true)
            end
          end

          context 'when tasks are not terminated in time' do
            let(:wait_for_termination_response) { false }

            it 'stops all tasks and returns false' do
              expect(tasks.size).to eq(9)
              expect(tasks).to all(receive(:kill).once)
              expect(tasks).to all(receive(:wait_for_termination).with(1).once)

              expect(periodic_updater.stop_updates).to be(false)
            end
          end
        end
      end
    end

    describe '#update_deploying_count' do
      let(:deploying_count) { 7 }

      before do
        allow(VCAP::CloudController::DeploymentModel).to receive(:deploying_count).and_return(deploying_count)
        allow(statsd_updater).to receive(:update_deploying_count)
        allow(prometheus_updater).to receive(:update_deploying_count)
      end

      it 'sends the number of deploying deployments' do
        periodic_updater.update_deploying_count

        expect(statsd_updater).to have_received(:update_deploying_count).with(deploying_count)
        expect(prometheus_updater).to have_received(:update_deploying_count).with(deploying_count)
      end
    end

    describe '#update_user_count' do
      before do
        allow(statsd_updater).to receive(:update_user_count)
        allow(prometheus_updater).to receive(:update_user_count)
      end

      it 'includes the number of users' do
        4.times { VCAP::CloudController::User.create(guid: SecureRandom.uuid) }

        periodic_updater.update_user_count

        expect(statsd_updater).to have_received(:update_user_count).with(VCAP::CloudController::User.count)
        expect(prometheus_updater).to have_received(:update_user_count).with(VCAP::CloudController::User.count)
      end
    end

    describe '#update_job_queue_length' do
      before do
        allow(statsd_updater).to receive(:update_job_queue_length)
        allow(prometheus_updater).to receive(:update_job_queue_length)
      end

      context 'when local queue has pending jobs' do
        it 'emits the correct count' do
          Delayed::Job.enqueue(
            VCAP::CloudController::Jobs::Runtime::EventsCleanup.new(1),
            queue: VCAP::CloudController::Jobs::Queues.local(VCAP::CloudController::Config.config)
          )
          periodic_updater.update_job_queue_length

          expected_pending_job_count_by_queue = {
            'cc-api-0': 1
          }
          expected_total = 1

          expect(statsd_updater).to have_received(:update_job_queue_length).with(expected_pending_job_count_by_queue, expected_total)
          expect(prometheus_updater).to have_received(:update_job_queue_length).with(expected_pending_job_count_by_queue)
        end
      end

      context 'when local queue does not have pending jobs' do
        it 'emits the local queue as 0 for discoverability' do
          periodic_updater.update_job_queue_length

          expected_pending_job_count_by_queue = {
            'cc-api-0': 0
          }
          expected_total = 0

          expect(statsd_updater).to have_received(:update_job_queue_length).with(expected_pending_job_count_by_queue, expected_total)
          expect(prometheus_updater).to have_received(:update_job_queue_length).with(expected_pending_job_count_by_queue)
        end
      end

      it 'includes the length of the delayed job queue and the total' do
        Delayed::Job.enqueue(VCAP::CloudController::Jobs::Runtime::EventsCleanup.new(1), queue: 'cc_local')
        Delayed::Job.enqueue(VCAP::CloudController::Jobs::Runtime::EventsCleanup.new(1), queue: 'cc_local')
        Delayed::Job.enqueue(VCAP::CloudController::Jobs::Runtime::EventsCleanup.new(1), queue: 'cc_generic')

        periodic_updater.update_job_queue_length

        expected_pending_job_count_by_queue = {
          cc_local: 2,
          cc_generic: 1,
          'cc-api-0': 0
        }
        expected_total = 3

        expect(statsd_updater).to have_received(:update_job_queue_length).with(expected_pending_job_count_by_queue, expected_total)
        expect(prometheus_updater).to have_received(:update_job_queue_length).with(expected_pending_job_count_by_queue)
      end

      it 'finds jobs which have not been attempted yet' do
        Delayed::Job.enqueue(VCAP::CloudController::Jobs::Runtime::EventsCleanup.new(1), queue: 'cc_local')
        Delayed::Job.enqueue(VCAP::CloudController::Jobs::Runtime::EventsCleanup.new(1), queue: 'cc_generic')

        periodic_updater.update_job_queue_length

        expected_pending_job_count_by_queue = {
          cc_local: 1,
          cc_generic: 1,
          'cc-api-0': 0
        }
        expected_total = 2

        expect(statsd_updater).to have_received(:update_job_queue_length).with(expected_pending_job_count_by_queue, expected_total)
        expect(prometheus_updater).to have_received(:update_job_queue_length).with(expected_pending_job_count_by_queue)
      end

      it 'ignores jobs that have already been attempted' do
        job = VCAP::CloudController::Jobs::Runtime::EventsCleanup.new(1)
        Delayed::Job.enqueue(job, queue: 'cc_generic', attempts: 1)

        periodic_updater.update_job_queue_length

        expected_pending_job_count_by_queue = {
          'cc-api-0': 0
        }
        expected_total = 0

        expect(statsd_updater).to have_received(:update_job_queue_length).with(expected_pending_job_count_by_queue, expected_total)
        expect(prometheus_updater).to have_received(:update_job_queue_length).with(expected_pending_job_count_by_queue)
      end

      it '"resets" pending job count to 0 after they have been emitted' do
        Delayed::Job.enqueue(VCAP::CloudController::Jobs::Runtime::EventsCleanup.new(1), queue: 'cc_local')
        Delayed::Job.enqueue(VCAP::CloudController::Jobs::Runtime::EventsCleanup.new(1), queue: 'cc_generic')
        periodic_updater.update_job_queue_length

        expected_pending_job_count_by_queue = {
          cc_local: 1,
          cc_generic: 1,
          'cc-api-0': 0
        }
        expected_total = 2

        expect(statsd_updater).to have_received(:update_job_queue_length).with(expected_pending_job_count_by_queue, expected_total)
        expect(prometheus_updater).to have_received(:update_job_queue_length).with(expected_pending_job_count_by_queue)

        Delayed::Job.dataset.delete
        periodic_updater.update_job_queue_length
        expected_pending_job_count_by_queue = {
          cc_local: 0,
          cc_generic: 0,
          'cc-api-0': 0
        }
        expected_total = 0

        expect(statsd_updater).to have_received(:update_job_queue_length).with(expected_pending_job_count_by_queue, expected_total)
        expect(prometheus_updater).to have_received(:update_job_queue_length).with(expected_pending_job_count_by_queue)
      end
    end

    describe '#update_job_queue_load' do
      before do
        allow(statsd_updater).to receive(:update_job_queue_load)
        allow(prometheus_updater).to receive(:update_job_queue_load)
      end

      context 'when there are pending jobs ready to run in the local queue' do
        it 'emits the correct count' do
          Delayed::Job.enqueue(
            VCAP::CloudController::Jobs::Runtime::EventsCleanup.new(1),
            queue: VCAP::CloudController::Jobs::Queues.local(VCAP::CloudController::Config.config),
            run_at: Time.now
          )
          periodic_updater.update_job_queue_load

          expected_pending_job_queue_load = {
            'cc-api-0': 1
          }
          expected_total = 1

          expect(statsd_updater).to have_received(:update_job_queue_load).with(expected_pending_job_queue_load, expected_total)
          expect(prometheus_updater).to have_received(:update_job_queue_load).with(expected_pending_job_queue_load)
        end
      end

      context 'when local queue does not have pending jobs' do
        it 'emits the local queue load as 0 for discoverability' do
          periodic_updater.update_job_queue_load

          expected_pending_job_queue_load = {
            'cc-api-0': 0
          }
          expected_total = 0

          expect(statsd_updater).to have_received(:update_job_queue_load).with(expected_pending_job_queue_load, expected_total)
          expect(prometheus_updater).to have_received(:update_job_queue_load).with(expected_pending_job_queue_load)
        end
      end

      it 'includes the load of the delayed job queue and the total' do
        Delayed::Job.enqueue(VCAP::CloudController::Jobs::Runtime::EventsCleanup.new(1), queue: 'cc_local', run_at: Time.now)
        Delayed::Job.enqueue(VCAP::CloudController::Jobs::Runtime::EventsCleanup.new(1), queue: 'cc_local', run_at: Time.now)
        Delayed::Job.enqueue(VCAP::CloudController::Jobs::Runtime::EventsCleanup.new(1), queue: 'cc_generic', run_at: Time.now)

        periodic_updater.update_job_queue_load

        expected_pending_job_queue_load = {
          cc_local: 2,
          cc_generic: 1,
          'cc-api-0': 0
        }
        expected_total = 3

        expect(statsd_updater).to have_received(:update_job_queue_load).with(expected_pending_job_queue_load, expected_total)
        expect(prometheus_updater).to have_received(:update_job_queue_load).with(expected_pending_job_queue_load)
      end

      it 'does not contain failed jobs in job queue load metric' do
        Delayed::Job.enqueue(VCAP::CloudController::Jobs::Runtime::EventsCleanup.new(1), queue: 'cc_local', failed_at: Time.now + 60, run_at: Time.now)
        Delayed::Job.enqueue(VCAP::CloudController::Jobs::Runtime::EventsCleanup.new(1), queue: 'cc_local', run_at: Time.now)
        Delayed::Job.enqueue(VCAP::CloudController::Jobs::Runtime::EventsCleanup.new(1), queue: 'cc_generic', failed_at: Time.now + 60, run_at: Time.now)
        Delayed::Job.enqueue(VCAP::CloudController::Jobs::Runtime::EventsCleanup.new(1), queue: 'cc_generic', run_at: Time.now)

        periodic_updater.update_job_queue_load

        expected_pending_job_queue_load = {
          cc_local: 1,
          cc_generic: 1,
          'cc-api-0': 0
        }
        expected_total = 2
        expect(statsd_updater).to have_received(:update_job_queue_load).with(expected_pending_job_queue_load, expected_total)
        expect(prometheus_updater).to have_received(:update_job_queue_load).with(expected_pending_job_queue_load)
      end
    end

    describe '#update_failed_job_count' do
      before do
        allow(statsd_updater).to receive(:update_failed_job_count)
        allow(prometheus_updater).to receive(:update_failed_job_count)
      end

      context 'when local queue has failed jobs' do
        it 'emits the correct count' do
          Delayed::Job.enqueue(
            VCAP::CloudController::Jobs::Runtime::EventsCleanup.new(1),
            queue: VCAP::CloudController::Jobs::Queues.local(VCAP::CloudController::Config.config)
          )
          Delayed::Job.dataset.update(failed_at: Time.now.utc)
          periodic_updater.update_failed_job_count

          expected_failed_jobs_by_queue = {
            'cc-api-0': 1
          }
          expected_total = 1

          expect(statsd_updater).to have_received(:update_failed_job_count).with(expected_failed_jobs_by_queue, expected_total)
          expect(prometheus_updater).to have_received(:update_failed_job_count).with(expected_failed_jobs_by_queue)
        end
      end

      context 'when local queue does not have failed jobs' do
        it 'emits the local queue as 0 for discoverability' do
          Delayed::Job.enqueue(
            VCAP::CloudController::Jobs::Runtime::EventsCleanup.new(1),
            queue: VCAP::CloudController::Jobs::Queues.local(VCAP::CloudController::Config.config)
          )
          periodic_updater.update_failed_job_count

          expected_failed_jobs_by_queue = {
            'cc-api-0': 0
          }
          expected_total = 0

          expect(statsd_updater).to have_received(:update_failed_job_count).with(expected_failed_jobs_by_queue, expected_total)
          expect(prometheus_updater).to have_received(:update_failed_job_count).with(expected_failed_jobs_by_queue)
        end
      end

      it 'includes the number of failed jobs in the delayed job queue with a total and sends it to all updaters' do
        Delayed::Job.enqueue(VCAP::CloudController::Jobs::Runtime::EventsCleanup.new(5), queue: 'cc_local')
        Delayed::Job.enqueue(VCAP::CloudController::Jobs::Runtime::EventsCleanup.new(5), queue: 'cc_local')
        Delayed::Job.enqueue(VCAP::CloudController::Jobs::Runtime::EventsCleanup.new(5), queue: 'cc_generic')
        Delayed::Job.dataset.update(failed_at: Time.now.utc)
        Delayed::Job.enqueue(VCAP::CloudController::Jobs::Runtime::EventsCleanup.new(5), queue: 'cc_local')
        Delayed::Job.enqueue(VCAP::CloudController::Jobs::Runtime::EventsCleanup.new(5), queue: 'cc_generic')

        periodic_updater.update_failed_job_count

        expected_failed_jobs_by_queue = {
          cc_local: 2,
          cc_generic: 1,
          'cc-api-0': 0
        }
        expected_total = 3

        expect(statsd_updater).to have_received(:update_failed_job_count).with(expected_failed_jobs_by_queue, expected_total)
        expect(prometheus_updater).to have_received(:update_failed_job_count).with(expected_failed_jobs_by_queue)
      end

      it '"resets" failed job count to 0 after they have been emitted' do
        Delayed::Job.enqueue(VCAP::CloudController::Jobs::Runtime::EventsCleanup.new(1), queue: 'cc_local')
        Delayed::Job.enqueue(VCAP::CloudController::Jobs::Runtime::EventsCleanup.new(1), queue: 'cc_generic')
        Delayed::Job.dataset.update(failed_at: Time.now.utc)
        periodic_updater.update_failed_job_count

        expected_failed_jobs_by_queue = {
          cc_local: 1,
          cc_generic: 1,
          'cc-api-0': 0
        }
        expected_total = 2

        expect(statsd_updater).to have_received(:update_failed_job_count).with(expected_failed_jobs_by_queue, expected_total)
        expect(prometheus_updater).to have_received(:update_failed_job_count).with(expected_failed_jobs_by_queue)

        Delayed::Job.dataset.delete
        periodic_updater.update_failed_job_count
        expected_failed_jobs_by_queue = {
          cc_local: 0,
          cc_generic: 0,
          'cc-api-0': 0
        }
        expected_total = 0

        expect(statsd_updater).to have_received(:update_failed_job_count).with(expected_failed_jobs_by_queue, expected_total)
        expect(prometheus_updater).to have_received(:update_failed_job_count).with(expected_failed_jobs_by_queue)
      end
    end

    describe '#update_vitals' do
      before do
        allow(statsd_updater).to receive(:update_vitals)
        allow(prometheus_updater).to receive(:update_vitals)

        allow(VCAP::Stats).to receive_messages(process_memory_bytes_and_cpu: [1.1, 2], cpu_load_average: 0.5, memory_used_bytes: 542, memory_free_bytes: 927)
        allow_any_instance_of(VCAP::HostSystem).to receive(:num_cores).and_return(4)
      end

      it 'update the vitals on all updaters' do
        periodic_updater.update_vitals

        expect(statsd_updater).to have_received(:update_vitals) do |expected_vitals|
          expect(expected_vitals[:uptime]).to be_within(1).of(Time.now.to_i - start_time.to_i)
          expect(expected_vitals[:cpu_load_avg]).to eq(0.5)
          expect(expected_vitals[:mem_used_bytes]).to eq(542)
          expect(expected_vitals[:mem_free_bytes]).to eq(927)
          expect(expected_vitals[:mem_bytes]).to eq(1.1.to_i)
          expect(expected_vitals[:cpu]).to eq(2.to_f)
          expect(expected_vitals[:num_cores]).to eq(4)
        end

        expect(prometheus_updater).to have_received(:update_vitals) do |expected_vitals|
          expect(expected_vitals[:started_at]).to eq(start_time.to_i)
          expect(expected_vitals[:cpu_load_avg]).to eq(0.5)
          expect(expected_vitals[:mem_used_bytes]).to eq(542)
          expect(expected_vitals[:mem_free_bytes]).to eq(927)
          expect(expected_vitals[:mem_bytes]).to eq(1.1.to_i)
          expect(expected_vitals[:num_cores]).to eq(4)
        end
      end
    end

    describe '#update_log_counts' do
      let(:expected) do
        {
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
      end

      let(:count) do
        {
          'off' => 1,
          'fatal' => 2,
          'error' => 3,
          'warn' => 4,
          'info' => 5,
          'debug' => 6,
          'debug1' => 7,
          'debug2' => 8,
          'all' => 9
        }
      end

      before do
        allow(statsd_updater).to receive(:update_log_counts)

        allow(log_counter).to receive(:counts).and_return(count)
      end

      it 'update the log counts on all updaters' do
        periodic_updater.update_log_counts

        expect(statsd_updater).to have_received(:update_log_counts).with(expected)
      end

      it 'fills in zeros for levels without counts' do
        count.delete('info')
        expected[:info] = 0

        periodic_updater.update_log_counts

        expect(statsd_updater).to have_received(:update_log_counts).with(expected)
      end
    end

    describe '#update_webserver_stats' do
      before do
        allow(prometheus_updater).to receive(:update_webserver_stats_puma)
      end

      it 'sends stats to the prometheus updater' do
        periodic_updater.update_webserver_stats

        expected_worker_count = 2
        expected_worker_stats = [
          { started_at: 1_701_263_705, index: 0, pid: 123, thread_count: 1, backlog: 0, busy_threads: 0, pool_capacity: 1, requests_count: 9 },
          { started_at: 1_701_263_710, index: 1, pid: 234, thread_count: 2, backlog: 1, busy_threads: 1, pool_capacity: 2, requests_count: 10 }
        ]
        expect(prometheus_updater).to have_received(:update_webserver_stats_puma).with(expected_worker_count, expected_worker_stats)
      end
    end

    describe '#catch_error' do
      it 'calls a block' do
        was_called = false
        periodic_updater.catch_error { was_called = true }
        expect(was_called).to be true
      end

      it 'swallows errors' do
        allow(logger).to receive(:info)
        expect do
          periodic_updater.catch_error { raise 'RDoom' }
        end.not_to raise_error
      end

      it 'logs errors' do
        exception = RuntimeError.new('The periodic metrics task encountered an error: boom')
        allow(logger).to receive(:info)
        periodic_updater.catch_error { raise exception }
        expect(logger).to have_received(:info).with(exception)
      end
    end

    describe 'task list configuration' do
      describe 'with vitals task only' do
        let(:vitals_updater) do
          PeriodicUpdater.new(start_time, log_counter, logger, statsd_updater, prometheus_updater, task_list: [PeriodicUpdater::VITALS_TASK])
        end

        before do
          allow(statsd_updater).to receive(:update_vitals)
          allow(prometheus_updater).to receive(:update_vitals)
        end

        it 'only sets up one timer task' do
          vitals_updater.setup_updates

          expect(vitals_updater.instance_variable_get(:@update_tasks).length).to eq(1)
        end

        it 'executes the vitals task' do
          vitals_updater.update_vitals

          expect(statsd_updater).to have_received(:update_vitals)
          expect(prometheus_updater).to have_received(:update_vitals)
        end
      end

      describe 'with multiple specific tasks' do
        let(:custom_updater) do
          PeriodicUpdater.new(
            start_time,
            log_counter,
            logger,
            statsd_updater,
            prometheus_updater,
            task_list: [PeriodicUpdater::VITALS_TASK, PeriodicUpdater::LOG_COUNTS_TASK]
          )
        end

        it 'sets up timer tasks for specified tasks only' do
          allow(statsd_updater).to receive(:update_vitals)
          allow(statsd_updater).to receive(:update_log_counts)
          allow(prometheus_updater).to receive(:update_vitals)

          custom_updater.setup_updates

          expect(custom_updater.instance_variable_get(:@update_tasks).length).to eq(2)
        end
      end

      describe 'default ALL_TASKS behavior' do
        it 'uses all tasks when no task_list is provided' do
          expect(periodic_updater.instance_variable_get(:@task_list)).to eq(PeriodicUpdater::ALL_TASKS)
        end
      end
    end
  end
end
