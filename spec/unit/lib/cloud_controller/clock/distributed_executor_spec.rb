require 'spec_helper'
require 'timecop'
require 'cloud_controller/clock/distributed_executor'

module VCAP::CloudController
  RSpec.describe DistributedExecutor do
    let(:job_name) { SecureRandom.uuid }

    before do
      Timecop.freeze
    end

    after do
      Timecop.return
    end

    context 'when the job has never been run' do
      it 'executes the block' do
        executed = false
        DistributedExecutor.new.execute_job name: job_name, interval: 1.minute, fudge: 1.second, timeout: 5.minutes do
          executed = true
        end

        expect(executed).to be(true)
      end
    end

    context 'when the job has already been run in the interval' do
      before do
        DistributedExecutor.new.execute_job(name: job_name, interval: 1.minute, fudge: 2.second, timeout: 5.minutes) {}
      end

      it 'does NOT execute the block' do
        executed = false
        DistributedExecutor.new.execute_job name: job_name, interval: 1.minute, fudge: 2.second, timeout: 5.minutes do
          executed = true
        end

        expect(executed).to be(false)
      end

      context 'but time remaining in the interval is smaller than the fudge factor' do
        before do
          Timecop.travel(Time.now.utc + 1.minute - 1.second)
        end

        it 'executes the block to account for processing time for the previous clock job' do
          executed = false
          DistributedExecutor.new.execute_job name: job_name, interval: 1.minute, fudge: 1.second, timeout: 5.minutes do
            executed = true
          end

          expect(executed).to be(true)
        end
      end
    end

    context 'when the job has run, but not in the last interval' do
      before do
        DistributedExecutor.new.execute_job(name: job_name, interval: 1.minute, fudge: 2.second, timeout: 5.minutes) {}
        Timecop.travel(Time.now.utc + 1.minute)
      end

      it 'executes the block' do
        executed = false
        DistributedExecutor.new.execute_job name: job_name, interval: 1.minute, fudge: 1.second, timeout: 5.minutes do
          executed = true
        end

        expect(executed).to be(true)
      end
    end

    it 'runs the passed block only once when there are multiple executors', isolation: :truncation do
      threads = []
      counter = 0

      10.times do
        threads << Thread.new do
          DistributedExecutor.new.execute_job name: job_name, interval: 1.minute, fudge: 1.second, timeout: 5.minutes do
            counter += 1
          end
        end
      end

      threads.each(&:join)
      expect(threads.any?(&:alive?)).to be(false)
      expect(counter).to eq(1)
    end

    context 'when the job errors' do
      it 'run the job again after interval has elapsed' do
        executed = false

        expect {
          DistributedExecutor.new.execute_job name: job_name, interval: 1.minute, fudge: 1.second, timeout: 5.minutes do
            raise 'fake-error'
          end
        }.to raise_error /fake-error/

        Timecop.travel(Time.now.utc + 1.minute)

        DistributedExecutor.new.execute_job name: job_name, interval: 1.minute, fudge: 1.second, timeout: 5.minutes do
          executed = true
        end

        expect(executed).to be(true)
      end
    end

    context 'when the job runs longer than its interval' do
      context 'when the job has NOT run before' do
        it 'does NOT execute the block if the previous run has not completed yet' do
          counter = 0

          DistributedExecutor.new.execute_job name: job_name, interval: 1.minute, fudge: 1.second, timeout: 5.minutes do
            Timecop.travel(Time.now.utc + 1.minute + 2.seconds)
            counter += 1

            DistributedExecutor.new.execute_job name: job_name, interval: 1.minute, fudge: 1.second, timeout: 5.minutes do
              counter += 1
            end
          end

          expect(counter).to eq(1)
        end
      end

      context 'when the job has run before' do
        before do
          DistributedExecutor.new.execute_job(name: job_name, interval: 1.minute, fudge: 1.second, timeout: 5.minutes) {}
          Timecop.travel(Time.now.utc + 1.minute + 1.second)
        end

        it 'does NOT execute the block if the previous run has not completed yet' do
          counter = 0

          DistributedExecutor.new.execute_job name: job_name, interval: 1.minute, fudge: 1.second, timeout: 5.minutes do
            Timecop.travel(Time.now.utc + 1.minute + 1.second)
            counter += 1

            DistributedExecutor.new.execute_job name: job_name, interval: 1.minute, fudge: 1.second, timeout: 5.minutes do
              counter += 1
            end
          end

          expect(counter).to eq(1)
        end
      end
    end

    context 'when a job runs longer than its timeout' do
      it 'executes the block regardless to prevent missed completed timestamps from blocking all future jobs' do
        counter = 0

        DistributedExecutor.new.execute_job name: job_name, interval: 1.minute, fudge: 1.second, timeout: 5.minutes do
          Timecop.travel(Time.now.utc + 5.minutes + 1.second)
          counter += 1

          DistributedExecutor.new.execute_job name: job_name, interval: 1.minute, fudge: 1.second, timeout: 5.minutes do
            counter += 1
          end
        end

        expect(counter).to eq(2)
      end
    end
  end
end
