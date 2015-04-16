require 'spec_helper'

module VCAP::CloudController
  module Jobs
    describe DeleteActionJob do
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
            expect(job.timeout_error).to be_a(VCAP::Errors::ApiError)
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
