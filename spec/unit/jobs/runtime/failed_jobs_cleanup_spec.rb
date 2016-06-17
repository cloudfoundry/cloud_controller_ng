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

    RSpec.describe FailedJobsCleanup do
      let(:cutoff_age_in_days) { 2 }
      let(:worker) { Delayed::Worker.new }

      subject(:cleanup_job) { FailedJobsCleanup.new(cutoff_age_in_days) }

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
            expect {
              cleanup_job.perform
            }.not_to change { Delayed::Job.find(id: @delayed_job.id) }
          end
        end

        context 'failing jobs' do
          let(:run_at) { Time.now.utc - 1.day }
          let(:the_job) { FailingJob.new }

          context 'when younger than specified cut-off' do
            it 'the job is not removed' do
              expect {
                cleanup_job.perform
              }.not_to change { Delayed::Job.find(id: @delayed_job.id) }
            end
          end

          context 'when older than specified cut-off' do
            let(:run_at) { Time.now.utc - 3.days }

            it 'removes the job' do
              expect {
                cleanup_job.perform
              }.to change {
                Delayed::Job.find(id: @delayed_job.id)
              }.from(@delayed_job).to(nil)
            end
          end
        end
      end
    end
  end
end
