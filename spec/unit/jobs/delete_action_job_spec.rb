require 'spec_helper'

module VCAP::CloudController
  module Jobs
    describe DeleteActionJob do
      let(:delete_action) { double(:delete_action, delete: nil) }

      subject(:job) { DeleteActionJob.new(delete_action) }

      it 'calls the delete method on the delete_action object' do
        job.perform
        expect(delete_action).to have_received(:delete)
      end

      it { is_expected.to be_a_valid_job }

      it 'knows its job name' do
        expect(job.job_name_in_configuration).to equal(:delete_action_job)
      end
    end
  end
end
