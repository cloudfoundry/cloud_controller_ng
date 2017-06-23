require 'spec_helper'

module VCAP::CloudController
  module Jobs
    RSpec.describe LoggingContextJob do
      subject(:logging_context_job) do
        LoggingContextJob.new(handler, request_id)
      end
      let(:request_id) { 'abc123' }
      let(:background_logger) { instance_double(Steno::Logger).as_null_object }

      let(:handler) { double('Handler', error: nil, perform: 'fake-perform', max_attempts: 1, reschedule_at: Time.now) }

      before do
        allow(Steno).to receive(:logger).and_return(background_logger)
      end

      context '#perform' do
        it 'delegates to the handler' do
          expect(logging_context_job.perform).to eq('fake-perform')
        end

        it 'logs its parameters' do
          logging_context_job.perform
          expect(background_logger).to have_received(:info).with("about to run job #{handler.inspect}")
        end

        it "sets the thread-local VCAP Request ID during execution of the wrapped job's perform method" do
          expect(handler).to receive(:perform) do
            expect(::VCAP::Request.current_id).to eq request_id
          end

          logging_context_job.perform
        end

        it "restores the original VCAP Request ID after execution of the wrapped job's perform method" do
          random_request_id          = SecureRandom.uuid
          ::VCAP::Request.current_id = random_request_id

          logging_context_job.perform

          expect(::VCAP::Request.current_id).to eq random_request_id
        end

        it "restores the original VCAP Request ID after exception within execution of the wrapped job's perform method" do
          allow(handler).to receive(:perform) do
            raise 'runtime test exception'
          end

          random_request_id          = SecureRandom.uuid
          ::VCAP::Request.current_id = random_request_id

          expect { logging_context_job.perform }.to raise_error 'runtime test exception'

          expect(::VCAP::Request.current_id).to eq random_request_id
        end

        context 'when a BlobstoreError occurs' do
          it 'wraps the error in an ApiError' do
            allow(handler).to receive(:perform).and_raise(CloudController::Blobstore::BlobstoreError, 'oh no!')

            expect {
              logging_context_job.perform
            }.to raise_error(CloudController::Errors::ApiError, /three retries/)
          end
        end
      end

      context '#max_attempts' do
        it 'delegates to the handler' do
          expect(logging_context_job.max_attempts).to eq(1)
        end
      end

      context '#error(job, exception)' do
        let(:job) { double('Job', guid: 'gregid').as_null_object }
        let(:error_presenter) { instance_double(ErrorPresenter, to_hash: 'sanitized exception hash').as_null_object }

        before do
          allow(ErrorPresenter).to receive(:new).with('exception').and_return(error_presenter)
          allow(error_presenter).to receive(:log_message).and_return('log message')
        end

        it 'saves the exception on the job as cf_api_error' do
          expect(YAML).to receive(:dump).with('sanitized exception hash').and_return('marshaled hash')
          expect(job).to receive(:cf_api_error=).with('marshaled hash')
          expect(job).to receive(:save)

          logging_context_job.error(job, 'exception')
        end

        it 'calls the wrapped jobs error method' do
          allow(error_presenter).to receive(:client_error?).and_return(true)
          expect(handler).to receive(:error).with(job, 'exception')
          expect(Steno).to receive(:logger).with('cc.background').and_return(background_logger)
          expect(background_logger).to receive(:info).with('log message', job_guid: 'gregid')
          logging_context_job.error(job, 'exception')
        end

        it 'sets the thread-local VCAP Request ID while logging method' do
          expect(background_logger).to receive(:info) do
            expect(::VCAP::Request.current_id).to eq request_id
          end

          logging_context_job.error(job, 'exception')
        end

        it "restores the original VCAP Request ID after execution of the wrapped job's perform method" do
          random_request_id          = SecureRandom.uuid
          ::VCAP::Request.current_id = random_request_id

          logging_context_job.error(job, 'exception')

          expect(::VCAP::Request.current_id).to eq random_request_id
        end

        it "restores the original VCAP Request ID after exception within execution of the wrapped job's perform method" do
          allow(handler).to receive(:error) do
            raise 'runtime test exception'
          end

          random_request_id          = SecureRandom.uuid
          ::VCAP::Request.current_id = random_request_id

          expect { logging_context_job.error(job, 'exception') }.to raise_error 'runtime test exception'

          expect(::VCAP::Request.current_id).to eq random_request_id
        end

        context 'when the error is a client error' do
          before do
            allow(error_presenter).to receive(:client_error?).and_return(true)
          end

          it 'logs the unsanitized information' do
            expect(Steno).to receive(:logger).with('cc.background').and_return(background_logger)
            expect(background_logger).to receive(:info).with('log message', job_guid: 'gregid')
            logging_context_job.error(job, 'exception')
          end
        end

        context 'when the error is a server error' do
          before do
            allow(error_presenter).to receive(:client_error?).and_return(false)
          end

          it 'logs the unsanitized information as an error' do
            expect(Steno).to receive(:logger).with('cc.background').and_return(background_logger)
            expect(background_logger).to receive(:error).with('log message', job_guid: 'gregid')
            logging_context_job.error(job, 'exception')
          end
        end

        describe 'job priority' do
          context 'when the job priority starts at 0' do
            before do
              allow(job).to receive(:priority).and_return(0)
            end

            it 'deprioritizes the job to priority 1' do
              logging_context_job.error(job, 'exception')

              expect(job).to have_received(:priority=).with(1).ordered
              expect(job).to have_received(:save).ordered
            end
          end

          context 'when the job priority is greater than 0' do
            before do
              allow(job).to receive(:priority).and_return(17)
            end

            it 'doubles the job priority' do
              logging_context_job.error(job, 'exception')

              expect(job).to have_received(:priority=).with(34).ordered
              expect(job).to have_received(:save).ordered
            end
          end
        end
      end

      describe '#reschedule_at' do
        it 'delegates to the handler' do
          time     = Time.now
          attempts = 5
          expect(logging_context_job.reschedule_at(time, attempts)).to eq(handler.reschedule_at(time, attempts))
        end
      end
    end
  end
end
