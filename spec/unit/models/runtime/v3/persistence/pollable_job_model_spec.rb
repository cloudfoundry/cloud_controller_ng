require 'spec_helper'

module VCAP::CloudController
  RSpec.describe PollableJobModel do
    describe '#complete?' do
      context 'when the state is complete' do
        let(:job) { PollableJobModel.make(state: 'COMPLETE') }

        it 'returns true' do
          expect(job.complete?).to be(true)
        end
      end

      context 'when the state is not complete' do
        let(:failed_job) { PollableJobModel.make(state: 'FAILED') }
        let(:processing_job) { PollableJobModel.make(state: 'PROCESSING') }

        it 'returns false' do
          expect(failed_job.complete?).to be(false)
          expect(processing_job.complete?).to be(false)
        end
      end
    end

    describe('#delayed_job_pollable_guid') do
      let(:delayed_job) { Delayed::Backend::Sequel::Job.create }
      let!(:pollable_job) { PollableJobModel.create(state: 'PROCESSING', delayed_job_guid: delayed_job.guid) }

      it 'returns the pollable guid for the given delayed job' do
        expect(PollableJobModel.delayed_job_pollable_guid(delayed_job)).to eq(pollable_job.guid)
      end
    end
  end
end
