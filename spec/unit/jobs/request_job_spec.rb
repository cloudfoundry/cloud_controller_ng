require 'spec_helper'

module VCAP::CloudController::Jobs
  describe RequestJob do
    let(:wrapped_job) { double('InnerJob', max_attempts: 2, reschedule_at: Time.now) }
    let(:request_id) { 'abc123' }
    subject(:request_job) { RequestJob.new(wrapped_job, request_id) }

    describe '#perform' do
      before do
        allow(wrapped_job).to receive(:perform)
      end

      it 'calls perform on the wrapped job' do
        request_job.perform
        expect(wrapped_job).to have_received(:perform)
      end

      it "sets the thread-local VCAP Request ID during execution of the wrapped job's perform method" do
        allow(wrapped_job).to receive(:perform) do
          expect(::VCAP::Request.current_id).to eq request_id
        end

        request_job.perform
      end

      it "restores the original VCAP Request ID after execution of the wrapped job's perform method" do
        random_request_id = SecureRandom.uuid
        ::VCAP::Request.current_id = random_request_id

        request_job.perform

        expect(::VCAP::Request.current_id).to eq random_request_id
      end

      it "restores the original VCAP Request ID after exception within execution of the wrapped job's perform method" do
        allow(wrapped_job).to receive(:perform) do
          raise 'runtime test exception'
        end

        random_request_id = SecureRandom.uuid
        ::VCAP::Request.current_id = random_request_id

        expect { request_job.perform }.to raise_error, 'runtime test exception'

        expect(::VCAP::Request.current_id).to eq random_request_id
      end
    end

    context '#max_attempts' do
      it 'delegates to the handler' do
        expect(subject.max_attempts).to eq(2)
      end
    end

    describe '#reschedule_at' do
      it 'delegates to the inner job' do
        time = Time.now
        attempts = 5
        expect(request_job.reschedule_at(time, attempts)).to eq(wrapped_job.reschedule_at(time, attempts))
      end
    end
  end
end
