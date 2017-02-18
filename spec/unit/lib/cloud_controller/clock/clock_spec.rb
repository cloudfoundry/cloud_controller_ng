require 'spec_helper'
require 'cloud_controller/clock/clock'

module VCAP::CloudController
  RSpec.describe Clock do
    subject(:clock) { Clock.new }

    let(:some_job_class) { Class.new { def initialize(*args); end } }
    let(:enqueuer) { instance_double(Jobs::Enqueuer, enqueue: nil) }

    before do
      Timecop.freeze(Time.now.utc)
      allow(Jobs::Enqueuer).to receive(:new).and_return(enqueuer)
    end

    after do
      Timecop.return
    end

    describe 'scheduling a daily event' do
      context 'when a job has never been run' do
        it 'schedules it at the given time' do
          job_name = 'fake'
          time = '12:00'
          allow(Clockwork).to receive(:every).with(1.day, 'fake.job', at: time).and_yield(nil)

          clock_opts = {
            name:     job_name,
            at:       time,
          }
          clock.schedule_daily_job(clock_opts) { some_job_class.new }

          expect(Jobs::Enqueuer).to have_received(:new).with(anything, { queue: 'cc-generic' })
          expect(enqueuer).to have_received(:enqueue)
        end
      end

      context 'when a job has been run within the last day' do
        it 'does not enqueue a new job' do
          job_name = 'fake'
          time = '12:00'
          allow(Clockwork).to receive(:every).with(1.day, 'fake.job', at: time).and_yield(nil)

          ClockJob.insert(name: job_name, last_started_at: Time.now.utc - 30.minute)

          clock_opts = {
            name:     job_name,
            at:       time,
          }
          clock.schedule_daily_job(clock_opts) { some_job_class.new }

          expect(Jobs::Enqueuer).to_not have_received(:new)
        end

        context 'and it ran more than 23h 59m ago' do
          it 'enqueues a new job to account for processing time for previous clock job update' do
            job_name = 'fake'
            time = '12:00'
            allow(Clockwork).to receive(:every).with(1.day, 'fake.job', at: time).and_yield(nil)

            ClockJob.insert(name: job_name, last_started_at: Time.now.utc - (1.day - 1.minute + 1.second))

            clock_opts = {
              name:     job_name,
              at:       time,
            }
            clock.schedule_daily_job(clock_opts) { some_job_class.new }

            expect(Jobs::Enqueuer).to have_received(:new).with(anything, { queue: 'cc-generic' })
            expect(enqueuer).to have_received(:enqueue)
          end
        end
      end

      context 'when a job has been run but NOT within the specified interval' do
        it 'does enqueues a new job' do
          job_name = 'fake'
          time = '12:00'
          allow(Clockwork).to receive(:every).with(1.day, 'fake.job', at: time).and_yield(nil)

          ClockJob.insert(name: job_name, last_started_at: Time.now.utc - 2.day)

          clock_opts = {
            name:     job_name,
            at:       time,
          }
          clock.schedule_daily_job(clock_opts) { some_job_class.new }

          expect(Jobs::Enqueuer).to have_received(:new).with(anything, { queue: 'cc-generic' })
          expect(enqueuer).to have_received(:enqueue)
        end
      end
    end

    describe 'scheduling a frequent worker job' do
      context 'when a job has never been run' do
        it 'schedules it at the given interval' do
          job_name = 'fake'
          interval = 507.seconds
          allow(Clockwork).to receive(:every).with(interval, 'fake.job', {}).and_yield(nil)

          clock_opts = {
            name:     job_name,
            interval: interval,
          }
          clock.schedule_frequent_worker_job(clock_opts) { some_job_class.new }

          expect(Jobs::Enqueuer).to have_received(:new).with(anything, { queue: 'cc-generic' })
          expect(enqueuer).to have_received(:enqueue)
        end
      end

      context 'when a job has been run within the specified interval' do
        it 'does not enqueue a new job' do
          job_name = 'fake'
          interval = 507.seconds
          allow(Clockwork).to receive(:every).with(interval, 'fake.job', {}).and_yield(nil)

          ClockJob.insert(name: job_name, last_started_at: Time.now.utc - 50.seconds)

          clock_opts = {
            name:     job_name,
            interval: interval,
          }
          clock.schedule_frequent_worker_job(clock_opts) { some_job_class.new }

          expect(Jobs::Enqueuer).to_not have_received(:new).with(anything, { queue: 'cc-generic' })
        end

        context 'and it falls within 1 second of the interval' do
          it 'enqueues a new job to account for processing time for previous clock job update' do
            job_name = 'fake'
            interval = 507.seconds
            allow(Clockwork).to receive(:every).with(interval, 'fake.job', {}).and_yield(nil)

            ClockJob.insert(name: job_name, last_started_at: Time.now.utc - interval + 1.second - 0.1.second)

            clock_opts = {
              name:     job_name,
              interval: interval,
            }
            clock.schedule_frequent_worker_job(clock_opts) { some_job_class.new }

            expect(Jobs::Enqueuer).to have_received(:new).with(anything, { queue: 'cc-generic' })
            expect(enqueuer).to have_received(:enqueue)
          end
        end
      end

      context 'when a job has been run but NOT within the specified interval' do
        it 'does enqueues a new job' do
          job_name = 'fake'
          interval = 507.seconds
          allow(Clockwork).to receive(:every).with(interval, 'fake.job', {}).and_yield(nil)

          ClockJob.insert(name: job_name, last_started_at: Time.now.utc - interval - 1)

          clock_opts = {
            name:     job_name,
            interval: interval,
          }
          10.times do
            clock.schedule_frequent_worker_job(clock_opts) { some_job_class.new }
          end

          expect(Jobs::Enqueuer).to have_received(:new).with(anything, { queue: 'cc-generic' })
          expect(enqueuer).to have_received(:enqueue)
        end
      end
    end

    describe 'scheduling a frequent inline job' do
      context 'when a job has never been run' do
        it 'schedules it at the given interval' do
          job_name = 'fake'
          interval = 507.seconds
          allow(Clockwork).to receive(:every).with(interval, 'fake.job', { thread: true }).and_yield(nil)

          enqueuer = instance_double(Jobs::Enqueuer)
          expect(enqueuer).to receive(:run_inline)

          allow(Jobs::Enqueuer).to receive(:new).with(anything).and_return(enqueuer)

          clock_opts = {
            name:     job_name,
            interval: interval,
          }
          clock.schedule_frequent_inline_job(clock_opts) { some_job_class.new }
        end
      end

      context 'when a job has been run within the specified interval' do
        it 'does not enqueue a new job' do
          job_name = 'fake'
          interval = 507.seconds
          allow(Clockwork).to receive(:every).with(interval, 'fake.job', { thread: true }).and_yield(nil)

          delay = Clock::FREQUENT_FUDGE_FACTOR + 1.second
          ClockJob.insert(name: job_name, last_started_at: Time.now.utc - interval + delay)

          clock_opts = {
            name:     job_name,
            interval: interval,
          }
          clock.schedule_frequent_inline_job(clock_opts) { some_job_class.new }
          expect(Jobs::Enqueuer).to_not have_received(:new)
        end

        context 'and it falls within 1 second of the interval' do
          it 'enqueues a new job to account for processing time for previous clock job update' do
            job_name = 'fake'
            interval = 507.seconds
            allow(Clockwork).to receive(:every).with(interval, 'fake.job', { thread: true }).and_yield(nil)

            ClockJob.insert(name: job_name, last_started_at: Time.now.utc - interval + 0.9.seconds)

            enqueuer = instance_double(Jobs::Enqueuer)
            expect(enqueuer).to receive(:run_inline)

            allow(Jobs::Enqueuer).to receive(:new).with(anything).and_return(enqueuer)

            clock_opts = {
              name:     job_name,
              interval: interval,
            }
            clock.schedule_frequent_inline_job(clock_opts) { some_job_class.new }
          end
        end
      end

      context 'when a job has been run but NOT within the specified interval' do
        it 'does enqueues a new job' do
          job_name = 'fake'
          interval = 507.seconds
          allow(Clockwork).to receive(:every).with(interval, 'fake.job', { thread: true }).and_yield(nil)

          enqueuer = instance_double(Jobs::Enqueuer)
          expect(enqueuer).to receive(:run_inline)

          allow(Jobs::Enqueuer).to receive(:new).with(anything).and_return(enqueuer)

          clock_opts = {
            name:     job_name,
            interval: interval,
          }
          10.times do
            clock.schedule_frequent_inline_job(clock_opts) { some_job_class.new }
          end
        end
      end
    end
  end
end
