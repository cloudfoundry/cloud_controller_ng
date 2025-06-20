require 'spec_helper'

module VCAP::CloudController
  module Jobs::Runtime
    class FailingJob
      def perform
        raise 'Hell'
      end

      def failure; end

      def max_attempts
        1
      end
    end

    class SuccessJob
      def perform; end

      def max_attempts
        1
      end
    end

    RSpec.describe FailedJobsCleanup, job_context: :worker do
      let(:worker) { Delayed::Worker.new }

      subject(:cleanup_job) { FailedJobsCleanup.new(cutoff_age_in_days: 2, max_number_of_failed_delayed_jobs: 2) }

      it { is_expected.to be_a_valid_job }

      it 'knows its job name' do
        expect(cleanup_job.job_name_in_configuration).to equal(:failed_jobs)
      end

      describe '#perform' do
        before do
          Delayed::Worker.destroy_failed_jobs = false
          @delayed_job = Delayed::Job.enqueue(the_job, run_at: run_at, queue: worker.name, created_at: (Time.now.utc - 1.day))
          worker.work_off 1
        end

        context 'non-failing jobs' do
          let(:run_at) { Time.now.utc + 1.day }
          let(:the_job) { SuccessJob.new }

          it 'the job is not removed' do
            expect do
              cleanup_job.perform
            end.not_to(change { Delayed::Job.find(id: @delayed_job.id) })
          end
        end

        context 'failing jobs' do
          let(:run_at) { Time.now.utc - 1.day }
          let(:the_job) { FailingJob.new }

          context 'when younger than specified cut-off' do
            it 'the job is not removed' do
              expect do
                cleanup_job.perform
              end.not_to(change { Delayed::Job.find(id: @delayed_job.id) })
            end
          end

          context 'when older than specified cut-off' do
            let(:run_at) { Time.now.utc - 50.hours }

            it 'removes the job' do
              expect do
                cleanup_job.perform
              end.to change {
                Delayed::Job.find(id: @delayed_job.id)
              }.from(@delayed_job).to(nil)
            end

            context 'when job is orphaned' do
              it 'does not remove the job if it is not older than cut-off + 1 day' do
                Sequel::Model.db[:delayed_jobs].where(id: @delayed_job.id).update(failed_at: nil, locked_by: nil)
                expect do
                  cleanup_job.perform
                end.not_to(change { Delayed::Job.find(id: @delayed_job.id) })
              end
            end
          end

          context 'when a job is orphaned and older than the cut-off + 1 day' do
            let(:run_at) { Time.now.utc - 73.hours }

            it 'removes the job even if it is not failed and regardless of locked_by' do
              Sequel::Model.db[:delayed_jobs].where(id: @delayed_job.id).update(failed_at: nil, locked_by: 'some-worker', locked_at: Time.now.utc - 2.days)
              expect do
                cleanup_job.perform
              end.to change {
                Delayed::Job.find(id: @delayed_job.id)
              }.from(@delayed_job).to(nil)
            end

            it 'removes the job even if it is not failed and locked_by is nil' do
              Sequel::Model.db[:delayed_jobs].where(id: @delayed_job.id).update(failed_at: nil, locked_by: nil)
              expect do
                cleanup_job.perform
              end.to change {
                Delayed::Job.find(id: @delayed_job.id)
              }.from(@delayed_job).to(nil)
            end
          end

          context 'when the number of delayed jobs exceeds max_number_of_failed_delayed_jobs' do
            let(:run_at) { Time.now.utc }
            let(:the_job) { FailingJob.new }
            let(:the_job2) { SuccessJob.new }

            it 'removes the exceeding jobs' do
              Delayed::Worker.destroy_failed_jobs = false
              @delayed_job2 = Delayed::Job.enqueue(the_job, run_at: run_at, queue: worker.name, created_at: (Time.now.utc - 1.day))
              @delayed_job3 = Delayed::Job.enqueue(the_job, run_at: run_at, queue: worker.name, created_at: (Time.now.utc - 1.day))
              @delayed_job4 = Delayed::Job.enqueue(the_job, run_at: run_at, queue: worker.name, created_at: (Time.now.utc - 1.day))
              @delayed_job5 = Delayed::Job.enqueue(the_job2, run_at: run_at, queue: worker.name, created_at: (Time.now.utc - 1.day))
              @delayed_job6 = Delayed::Job.enqueue(the_job2, run_at: run_at, queue: worker.name, created_at: (Time.now.utc - 1.day))
              worker.work_off 5

              expect do
                cleanup_job.perform
              end.to change(Delayed::Job, :count).by(-2)
              expect(Delayed::Job.find(id: @delayed_job.id)).to be_nil
              expect(Delayed::Job.find(id: @delayed_job2.id)).to be_nil
            end
          end
        end
      end
    end
  end
end
