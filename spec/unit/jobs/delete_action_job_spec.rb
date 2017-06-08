require 'spec_helper'

module VCAP::CloudController
  module Jobs
    RSpec.describe DeleteActionJob do
      let(:user) { User.make(admin: true) }
      let(:delete_action) { double(SpaceDelete, delete: []) }
      let(:space) { Space.make(name: Sham.guid) }

      subject(:job) { DeleteActionJob.new(Space, space.guid, delete_action) }

      it { is_expected.to be_a_valid_job }

      it 'knows its job name' do
        expect(job.job_name_in_configuration).to equal(:delete_action_job)
      end

      it 'calls the delete action' do
        job.perform

        expect(delete_action).to have_received(:delete).with(Space.where(guid: space.guid))
      end

      describe 'DeleteActionJob callbacks' do
        let(:delete_action) { VCAP::CloudController::SpaceDelete.new('foo', 'foo') }

        context 'when the delayed job completes successfully' do
          context 'when there is an associated job model' do
            it 'marks the job model completed' do
              enqueued_job = VCAP::CloudController::Jobs::Enqueuer.new(job).enqueue
              job_model = VCAP::CloudController::JobModel.make(guid: enqueued_job.guid, state: JobModel::PROCESSING_STATE)
              successes, failures = Delayed::Worker.new.work_off

              expect(successes).to eq(1)
              expect(failures).to eq(0)

              expect(job_model.reload.state).to eq(JobModel::COMPLETE_STATE)
            end
          end

          context 'when there is NOT an associated job model' do
            it 'does NOT choke' do
              VCAP::CloudController::Jobs::Enqueuer.new(job).enqueue

              successes, failures = Delayed::Worker.new.work_off
              expect(successes).to eq(1)
              expect(failures).to eq(0)
            end
          end
        end

        context 'when the job fails' do
          before do
            allow_any_instance_of(VCAP::CloudController::Jobs::DeleteActionJob).to receive(:perform).and_raise
          end

          context 'when there is an associated job model' do
            it 'marks the job model failed' do
              enqueued_job = VCAP::CloudController::Jobs::Enqueuer.new(job).enqueue
              job_model = VCAP::CloudController::JobModel.make(guid: enqueued_job.guid, state: JobModel::PROCESSING_STATE)
              successes, failures = Delayed::Worker.new.work_off

              expect(successes).to eq(0)
              expect(failures).to eq(1)

              expect(job_model.reload.state).to eq(JobModel::FAILED_STATE)
            end
          end

          context 'when there is NOT an associated job model' do
            it 'does NOT choke' do
              VCAP::CloudController::Jobs::Enqueuer.new(job).enqueue

              successes, failures = Delayed::Worker.new.work_off
              expect(successes).to eq(0)
              expect(failures).to eq(1)
            end
          end
        end
      end

      describe 'the timeout error to use when the job times out' do
        context 'when the delete action has a timeout error' do
          let(:error) { StandardError.new('foo') }
          let(:delete_action) { double(SpaceDelete, delete: [], timeout_error: error) }

          it 'returns the custom timeout error' do
            expect(job.timeout_error).to eq(error)
          end
        end

        context 'when the delete action does not have a timeout error' do
          let(:delete_action) { double(SpaceDelete, delete: []) }

          it 'returns a generic timeout error' do
            expect(job.timeout_error).to be_a(CloudController::Errors::ApiError)
            expect(job.timeout_error.name).to eq('JobTimeout')
          end
        end
      end

      context 'when the delete action fails' do
        let(:delete_action) { double(SpaceDelete, delete: errors) }

        context 'with a single error' do
          let(:errors) { [StandardError.new] }

          it 'raises only that error' do
            expect { job.perform }.to raise_error(errors.first)
          end
        end

        context 'with multiple errors' do
          let(:errors) { [StandardError.new('foo'), StandardError.new('bar')] }

          it 'raises the first error' do
            expect { job.perform }.to raise_error(errors.first)
          end
        end
      end
    end
  end
end
