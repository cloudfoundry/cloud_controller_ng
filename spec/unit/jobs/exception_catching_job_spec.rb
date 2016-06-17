require 'spec_helper'

module VCAP::CloudController
  module Jobs
    RSpec.describe ExceptionCatchingJob do
      subject(:exception_catching_job) do
        ExceptionCatchingJob.new(handler)
      end

      let(:handler) { double('Handler', error: nil, perform: 'fake-perform', max_attempts: 1, reschedule_at: Time.now) }

      context '#perform' do
        it 'delegates to the handler' do
          expect(exception_catching_job.perform).to eq('fake-perform')
        end

        context 'when a BlobstoreError occurs' do
          it 'wraps the error in an ApiError' do
            allow(handler).to receive(:perform).and_raise(CloudController::Blobstore::BlobstoreError, 'oh no!')

            expect {
              exception_catching_job.perform
            }.to raise_error(CloudController::Errors::ApiError, /three retries/)
          end
        end
      end

      context '#max_attempts' do
        it 'delegates to the handler' do
          expect(exception_catching_job.max_attempts).to eq(1)
        end
      end

      context '#error(job, exception)' do
        let(:job) { double('Job').as_null_object }
        let(:error_presenter) { instance_double(ErrorPresenter, to_hash: 'sanitized exception hash').as_null_object }
        let(:background_logger) { instance_double(Steno::Logger).as_null_object }

        before do
          allow(Steno).to receive(:logger).and_return(background_logger)
          allow(ErrorPresenter).to receive(:new).with('exception').and_return(error_presenter)
          allow(error_presenter).to receive(:log_message).and_return('log message')
        end

        context 'when the error is a client error' do
          before do
            allow(error_presenter).to receive(:client_error?).and_return(true)
          end

          it 'logs the unsanitized information' do
            expect(Steno).to receive(:logger).with('cc.background').and_return(background_logger)
            expect(background_logger).to receive(:info).with('log message')
            exception_catching_job.error(job, 'exception')
          end
        end

        context 'when the error is a server error' do
          before do
            allow(error_presenter).to receive(:client_error?).and_return(false)
          end

          it 'logs the unsanitized information as an error' do
            expect(Steno).to receive(:logger).with('cc.background').and_return(background_logger)
            expect(background_logger).to receive(:error).with('log message')
            exception_catching_job.error(job, 'exception')
          end
        end

        it 'saves the exception on the job as cf_api_error' do
          expect(YAML).to receive(:dump).with('sanitized exception hash').and_return('marshaled hash')
          expect(job).to receive(:cf_api_error=).with('marshaled hash')
          expect(job).to receive(:save)

          exception_catching_job.error(job, 'exception')
        end

        it 'calls the wrapped jobs error method' do
          allow(error_presenter).to receive(:client_error?).and_return(true)
          expect(handler).to receive(:error).with(job, 'exception')
          expect(Steno).to receive(:logger).with('cc.background').and_return(background_logger)
          expect(background_logger).to receive(:info).with('log message')
          exception_catching_job.error(job, 'exception')
        end

        describe 'job priority' do
          context 'when the job priority starts at 0' do
            before do
              allow(job).to receive(:priority).and_return(0)
            end

            it 'deprioritizes the job to priority 1' do
              exception_catching_job.error(job, 'exception')

              expect(job).to have_received(:priority=).with(1).ordered
              expect(job).to have_received(:save).ordered
            end
          end

          context 'when the job priority is greater than 0' do
            before do
              allow(job).to receive(:priority).and_return(17)
            end

            it 'doubles the job priority' do
              exception_catching_job.error(job, 'exception')

              expect(job).to have_received(:priority=).with(34).ordered
              expect(job).to have_received(:save).ordered
            end
          end
        end
      end

      describe '#reschedule_at' do
        it 'delegates to the handler' do
          time = Time.now
          attempts = 5
          expect(exception_catching_job.reschedule_at(time, attempts)).to eq(handler.reschedule_at(time, attempts))
        end
      end
    end
  end
end
