require 'spec_helper'
require 'cloud_controller/clock/clock'

module VCAP::CloudController
  RSpec.describe Clock do
    subject(:clock) { Clock.new }

    let(:some_job_class) { Class.new {
      def initialize(*args); end
    }
    }
    let(:enqueuer) { instance_double(Jobs::Enqueuer, enqueue: nil, run_inline: nil) }

    before do
      allow(Jobs::Enqueuer).to receive(:new).and_return(enqueuer)
    end

    describe 'scheduling a daily job' do
      let(:priority) { 0 }

      it 'schedules with a 1 day interval at the given time with the given name and enqueues the job' do
        job_name = 'fake'
        time     = '12:00'

        scheduler = instance_double(DistributedScheduler)
        allow(DistributedScheduler).to receive(:new).and_return scheduler

        expect(scheduler).to receive(:schedule_periodic_job).with(
          interval: 1.day,
          name:     job_name,
          at:       time,
          fudge:    Clock::DAILY_FUDGE_FACTOR,
        ).and_yield

        clock_opts = {
          name:     job_name,
          at:       time,
          priority: priority
        }
        clock.schedule_daily_job(clock_opts) { some_job_class.new }

        expected_job_opts = { queue: 'cc-generic', priority: 0 }
        expect(Jobs::Enqueuer).to have_received(:new).with(instance_of(some_job_class), expected_job_opts)
        expect(enqueuer).to have_received(:enqueue)
      end

      context 'when a job has a priority' do
        let(:priority) { 1 }

        it 'schedules with a 1 day interval with the given priority' do
          job_name = 'fake-2'
          time     = '1:00'

          scheduler = instance_double(DistributedScheduler)
          allow(DistributedScheduler).to receive(:new).and_return scheduler

          expect(scheduler).to receive(:schedule_periodic_job).with(
            interval: 1.day,
            name:     job_name,
            at:       time,
            fudge:    Clock::DAILY_FUDGE_FACTOR,
          ).and_yield

          clock_opts = {
            name:     job_name,
            at:       time,
            priority: priority
          }
          clock.schedule_daily_job(clock_opts) { some_job_class.new }

          expected_job_opts = { queue: 'cc-generic', priority: priority }
          expect(Jobs::Enqueuer).to have_received(:new).with(instance_of(some_job_class), expected_job_opts)
          expect(enqueuer).to have_received(:enqueue)
        end
      end
    end

    describe 'scheduling a frequent worker job' do
      it 'schedules with the given interval with the given name and enqueues the job' do
        job_name = 'fake'
        interval = 507.seconds

        scheduler = instance_double(DistributedScheduler)
        allow(DistributedScheduler).to receive(:new).and_return scheduler

        expect(scheduler).to receive(:schedule_periodic_job).with(
          interval: interval,
          name:     job_name,
          fudge:    Clock::FREQUENT_FUDGE_FACTOR,
        ).and_yield

        clock_opts = {
          name:     job_name,
          interval: interval,
        }
        clock.schedule_frequent_worker_job(clock_opts) { some_job_class.new }

        expected_job_opts = { queue: 'cc-generic' }
        expect(Jobs::Enqueuer).to have_received(:new).with(instance_of(some_job_class), expected_job_opts)
        expect(enqueuer).to have_received(:enqueue)
      end
    end

    describe 'scheduling a frequent inline job' do
      it 'schedules with the given interval and name and executes the job inline in a thread with a timeout' do
        job_name = 'fake'
        interval = 507.seconds
        timeout  = 4.hours

        scheduler = instance_double(DistributedScheduler)
        allow(DistributedScheduler).to receive(:new).and_return scheduler

        expect(scheduler).to receive(:schedule_periodic_job).with(
          interval: interval,
          name:     job_name,
          fudge:    Clock::FREQUENT_FUDGE_FACTOR,
          thread:   true,
          timeout:  timeout,
        ).and_yield

        clock_opts = {
          name:     job_name,
          interval: interval,
          timeout:  timeout,
        }
        clock.schedule_frequent_inline_job(clock_opts) { some_job_class.new }

        expect(Jobs::Enqueuer).to have_received(:new).with(instance_of(some_job_class))
        expect(enqueuer).to have_received(:run_inline)
      end
    end
  end
end
