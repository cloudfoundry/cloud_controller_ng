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

    context 'when the job has already been run' do
      it 'runs the passed block only once', isolation: :truncation do
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

      context 'interval' do
        context 'when the interval for job has not elapsed' do
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

        context 'when the interval for the job has elapsed' do
          before do
            DistributedExecutor.new.execute_job(name: job_name, interval: 1.minute, fudge: 2.second, timeout: 5.minutes) {}
            Timecop.travel(Time.now.utc + 1.minute)
          end

          context 'and the job is not in progress' do
            it 'executes the block' do
              executed = false
              DistributedExecutor.new.execute_job name: job_name, interval: 1.minute, fudge: 1.second, timeout: 5.minutes do
                executed = true
              end

              expect(executed).to be(true)
            end
          end

          context 'and the job is in progress' do
            before do
              DistributedExecutor.new.execute_job(name: job_name, interval: 1.minute, fudge: 2.second, timeout: 5.minutes) {
                Delayed::Job.create!(queue: job_name, failed_at: nil, locked_at: Time.now)
              }
            end

            it 'does not execute the block' do
              executed = false
              DistributedExecutor.new.execute_job name: job_name, interval: 1.minute, fudge: 1.second, timeout: 5.minutes do
                executed = true
              end

              expect(executed).to be(false)
            end
          end
        end

        context 'when the job runs longer than its interval' do
          context 'when the job has NOT run before' do
            it 'does NOT execute the block if the previous run has not completed yet' do
              counter = 0

              DistributedExecutor.new.execute_job name: job_name, interval: 1.minute, fudge: 1.second, timeout: 5.minutes do
                Delayed::Job.create!(queue: job_name, failed_at: nil, locked_at: Time.now)
                counter += 1
                Timecop.travel(Time.now.utc + 1.minute + 2.seconds)

                DistributedExecutor.new.execute_job name: job_name, interval: 1.minute, fudge: 1.second, timeout: 5.minutes do
                  counter += 2
                end
              end

              expect(counter).to eq(1)
            end
          end

          context 'when the job has run before' do
            context 'when the job is "diego_sync"' do
              before do
                DistributedExecutor.new.execute_job(name: 'diego_sync', interval: 1.minute, fudge: 1.second, timeout: 5.minutes) {}
                Timecop.travel(Time.now.utc + 1.minute + 1.second)
              end

              it 'does NOT execute the block if the previous run has not completed yet' do
                counter = 0

                DistributedExecutor.new.execute_job name: 'diego_sync', interval: 1.minute, fudge: 1.second, timeout: 5.minutes do
                  Timecop.travel(Time.now.utc + 1.minute + 1.second)
                  counter += 1

                  DistributedExecutor.new.execute_job name: 'diego_sync', interval: 1.minute, fudge: 1.second, timeout: 5.minutes do
                    counter += 2
                  end
                end

                expect(counter).to eq(1)
              end
            end

            context 'when the job is not "diego_sync"' do
              before do
                DistributedExecutor.new.execute_job(name: job_name, interval: 1.minute, fudge: 1.second, timeout: 5.minutes) {}
                Timecop.travel(Time.now.utc + 1.minute + 1.second)
              end

              it 'does NOT execute the block if the previous run has not completed yet' do
                counter = 0

                DistributedExecutor.new.execute_job name: job_name, interval: 1.minute, fudge: 1.second, timeout: 5.minutes do
                  Delayed::Job.create!(queue: job_name, failed_at: nil, locked_at: Time.now)
                  Timecop.travel(Time.now.utc + 1.minute + 1.second)
                  counter += 1

                  DistributedExecutor.new.execute_job name: job_name, interval: 1.minute, fudge: 1.second, timeout: 5.minutes do
                    counter += 2
                  end
                end

                expect(counter).to eq(1)
              end
            end
          end
        end
      end

      context 'when the job errors' do
        before do
          DistributedExecutor.new.execute_job name: job_name, interval: 1.minute, fudge: 1.second, timeout: 5.minutes do
            Delayed::Job.create!(queue: job_name, failed_at: nil, locked_at: Time.now)
          end
        end

        context 'when the job timeout is nil' do
          context 'when the globally configured timeout is nil' do
            before do
              TestConfig.override(jobs: { global: { timeout_in_seconds: nil } })
              Timecop.travel(Time.now.utc + 10.minutes)
            end

            it 'does not schedule a new job' do
              executed = false

              DistributedExecutor.new.execute_job name: job_name, interval: 1.minute, fudge: 1.second, timeout: nil do
                executed = true
              end
              expect(executed).to be(false)
            end
          end
        end

        context 'when the job timeout has not expired' do
          before do
            Timecop.travel(Time.now.utc + 2.minutes)
          end

          it 'does not schedule a new job' do
            executed = false

            DistributedExecutor.new.execute_job name: job_name, interval: 1.minute, fudge: 1.second, timeout: 5.minutes do
              executed = true
            end
            expect(executed).to be(false)
          end
        end

        context 'when the job timeout has expired' do
          before do
            Timecop.travel(Time.now.utc + 6.minutes)
          end

          it 'schedules a new job' do
            executed = false

            DistributedExecutor.new.execute_job name: job_name, interval: 1.minute, fudge: 1.second, timeout: 5.minutes do
              executed = true
            end
            expect(executed).to be(true)
          end
        end
      end
    end
  end
end
