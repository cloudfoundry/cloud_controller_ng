require 'spec_helper'

module VCAP::CloudController
  RSpec.describe PollableJobModel do
    describe('.find_by_delayed_job') do
      let(:delayed_job) { Delayed::Backend::Sequel::Job.create }
      let!(:pollable_job) { PollableJobModel.create(state: 'PROCESSING', delayed_job_guid: delayed_job.guid) }

      it 'returns the PollableJobModel for the given DelayedJob' do
        result = PollableJobModel.find_by_delayed_job(delayed_job)
        expect(result).to be_present
        expect(result).to eq(pollable_job)
      end
    end

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

    describe '#resource_exists?' do
      context 'when the operation is a delete' do
        it 'returns true if the operation is in progress' do
          job = PollableJobModel.make(state: 'PROCESSING', operation: 'droplet.delete')
          expect(job.resource_exists?).to be(true)
        end

        it 'returns false if the operation is complete' do
          job = PollableJobModel.make(state: 'COMPLETE', operation: 'droplet.delete')
          expect(job.resource_exists?).to be(false)
        end
      end
    end
  end
end
