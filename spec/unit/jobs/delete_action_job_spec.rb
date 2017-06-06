require 'spec_helper'

module VCAP::CloudController
  module Jobs
    RSpec.describe DeleteActionJob do
      let(:user) { User.make(admin: true) }
      let(:delete_action) { double(SpaceDelete, delete: []) }
      let(:space) { Space.make(name: Sham.guid) }

      subject(:job) { DeleteActionJob.new(Space, space.guid, delete_action, 'space.delete') }

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

        it 'creates a historical job' do
          allow_any_instance_of(VCAP::CloudController::Jobs::DeleteActionJob).to receive(:success)
          enqueued_job = VCAP::CloudController::Jobs::Enqueuer.new(job).enqueue
          Delayed::Worker.new.work_off

          historical_job = HistoricalJobModel.last
          expect(HistoricalJobModel.count).to eq(1)
          expect(historical_job.guid).to eq(enqueued_job.guid)
          expect(historical_job.operation).to eq('space.delete')
          expect(historical_job.state).to eq(HistoricalJobModel::PROCESSING_STATE)
          expect(historical_job.resource_guid).to eq(space.guid)

          expect(Space.where(guid: space.guid)).to be_empty
        end

        it 'marks the historical job completed when the job completes successfully' do
          enqueued_job = VCAP::CloudController::Jobs::Enqueuer.new(job).enqueue
          Delayed::Worker.new.work_off

          historical_job = HistoricalJobModel.last
          expect(historical_job.guid).to eq(enqueued_job.guid)
          expect(historical_job.reload.state).to eq(HistoricalJobModel::COMPLETE_STATE)
        end

        it 'marks the historical job failed when the job fails' do
          allow_any_instance_of(VCAP::CloudController::Jobs::DeleteActionJob).to receive(:perform).and_raise

          enqueued_job = VCAP::CloudController::Jobs::Enqueuer.new(job).enqueue
          Delayed::Worker.new.work_off

          historical_job = HistoricalJobModel.last
          expect(historical_job.guid).to eq(enqueued_job.guid)
          expect(historical_job.reload.state).to eq(HistoricalJobModel::FAILED_STATE)
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
