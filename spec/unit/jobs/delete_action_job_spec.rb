require 'spec_helper'

module VCAP::CloudController
  module Jobs
    describe DeleteActionJob do
      let(:delete_action) { double(:delete_action, delete: []) }
      let(:fetcher) { double(:fetcher, fetch: nil) }

      subject(:job) { DeleteActionJob.new(fetcher, delete_action) }

      it 'calls the delete method on the delete_action object' do
        job.perform
        expect(delete_action).to have_received(:delete)
      end

      it 'calls the fetch method on the fetcher object' do
        job.perform
        expect(fetcher).to have_received(:fetch)
      end

      it { is_expected.to be_a_valid_job }

      it 'knows its job name' do
        expect(job.job_name_in_configuration).to equal(:delete_action_job)
      end
    end
  end
end
