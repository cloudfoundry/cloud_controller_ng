require 'spec_helper'

module VCAP::CloudController
  module Jobs
    describe DeleteActionJob do
      let(:delete_action) { double(:delete_action, delete: []) }
      let(:space) { Space.make }

      subject(:job) { DeleteActionJob.new(Space, space.guid, delete_action) }

      it { is_expected.to be_a_valid_job }

      it 'calls the delete method on the delete_action object' do
        job.perform
        expect(delete_action).to have_received(:delete).with([space])
      end

      it 'knows its job name' do
        expect(job.job_name_in_configuration).to equal(:delete_action_job)
      end

      context 'when the delete action fails' do
        let(:errors) { [ServiceInstanceDeletionError.new(nil)] }

        before do
          expect(delete_action).to receive(:delete).and_return(errors)
        end

        it 'raises an error' do
          expect { job.perform }.to raise_error
        end
      end
    end
  end
end
