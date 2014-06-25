require "spec_helper"

module VCAP::CloudController
  module Jobs
    describe ExceptionCatchingJob do
      subject(:exception_catching_job) do
        ExceptionCatchingJob.new(handler)
      end

      let(:handler) { double("Handler", perform: "fake-perform", max_attempts: 1) }

      context "#perform" do
        it "delegates to the handler" do
          expect(exception_catching_job.perform).to eq("fake-perform")
        end
      end

      context "#max_attempts" do
        it "delegates to the handler" do
          expect(exception_catching_job.max_attempts).to eq(1)
        end
      end

      context "#error(job, exception)" do
        let(:job) { double("Job").as_null_object }
        let(:error_presenter) { double("ErrorPresenter", error_hash: "sanitized exception hash").as_null_object }
        let(:background_logger) { double("Steno").as_null_object }

        before do
          allow(Steno).to receive(:logger).and_return(background_logger)
          allow(ErrorPresenter).to receive(:new).with("exception").and_return(error_presenter)
          allow(error_presenter).to receive(:log_message).and_return("log message")
        end

        context "when the error is a client error" do
          before do
            allow(error_presenter).to receive(:client_error?).and_return(true)
          end

          it "logs the unsanitized information" do
            expect(Steno).to receive(:logger).with("cc.background").and_return(background_logger)
            expect(background_logger).to receive(:info).with("log message")
            exception_catching_job.error(job, "exception")
          end
        end

        context "when the error is a server error" do
          before do
            allow(error_presenter).to receive(:client_error?).and_return(false)
          end

          it "logs the unsanitized information as an error" do
            expect(Steno).to receive(:logger).with("cc.background").and_return(background_logger)
            expect(background_logger).to receive(:error).with("log message")
            exception_catching_job.error(job, "exception")
          end
        end

        it "saves the exception on the job as cf_api_error" do
          expect(YAML).to receive(:dump).with("sanitized exception hash").and_return("marshaled hash")
          expect(job).to receive("cf_api_error=").with("marshaled hash")
          expect(job).to receive("save")

          exception_catching_job.error(job, "exception")
        end
      end
    end
  end
end