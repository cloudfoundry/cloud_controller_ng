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

      describe '#resource_type' do
        it 'returns a display name for the resource being deleted' do
          expect(job.resource_type).to eq('space')
        end

        context 'when the class contains the word Model' do
          subject(:job) { DeleteActionJob.new(DropletModel, 'unused', nil) }

          it 'returns a display name without the word Model' do
            expect(job.resource_type).to eq('droplet')
          end
        end
      end

      describe '#display_name' do
        it 'returns a display name for this action' do
          expect(job.display_name).to eq('space.delete')
        end

        context 'when the class contains the word Model' do
          subject(:job) { DeleteActionJob.new(DropletModel, 'unused', nil) }

          it 'returns a display name without the word Model' do
            expect(job.display_name).to eq('droplet.delete')
          end
        end
      end

      describe '#resource_guid' do
        it 'returns the given resource guid' do
          expect(job.resource_guid).to eq(space.guid)
        end
      end
    end
  end
end
