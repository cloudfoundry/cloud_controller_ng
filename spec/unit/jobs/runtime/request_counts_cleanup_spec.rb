require 'spec_helper'

module VCAP::CloudController
  module Jobs::Runtime
    RSpec.describe RequestCountsCleanup, job_context: :worker do
      let(:logger) { double(Steno::Logger, info: nil) }

      subject(:job) do
        RequestCountsCleanup.new
      end

      before do
        allow(Steno).to receive(:logger).and_return(logger)
      end

      it { is_expected.to be_a_valid_job }

      it 'can be enqueued' do
        expect(job).to respond_to(:perform)
      end

      describe '#perform' do
        it 'deletes request_counts that are no longer valid' do
          invalid_request_count = RequestCount.make(valid_until: 1.days.ago)
          expect {
            job.perform
          }.to change { invalid_request_count.exists? }.to(false)
          expect(logger).to have_received(:info).with(/Cleaning up no-longer-valid RequestCount rows/)
          expect(logger).to have_received(:info).with(/Cleaned up 1 RequestCount rows/)
        end

        it 'does not delete request_counts that are still valid' do
          valid_request_count = RequestCount.make(valid_until: 1.days.since)
          expect {
            job.perform
          }.not_to change { valid_request_count.exists? }.from(true)
          expect(logger).to have_received(:info).with(/Cleaning up no-longer-valid RequestCount rows/)
          expect(logger).to have_received(:info).with(/Cleaned up 0 RequestCount rows/)
        end

        it 'knows its job name' do
          expect(job.job_name_in_configuration).to equal(:request_counts_cleanup)
        end
      end
    end
  end
end
