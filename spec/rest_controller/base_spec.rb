require 'spec_helper'

describe VCAP::CloudController::RestController::Base do
  before do
    VCAP::CloudController::SecurityContext.stub(:current_user) { true }
  end

  let(:logger) { double(:logger, :debug => nil, :error => nil) }

  subject {
    VCAP::CloudController::RestController::Base.new(double(:config), logger, double(:env), double(:params, :[] => nil), double(:body))
  }

  describe "#dispatch" do
    context "when the dispatch is succesful" do
      it "should dispatch the request" do
        subject.should_receive(:to_s).with([:a, :b])
        subject.dispatch(:to_s, [:a, :b])
      end

      it "should log a debug message" do
        logger.should_receive(:debug).with(/dispatch.*to_s/i)
        subject.dispatch(:to_s)
      end

      context "when there is no current user" do
        it "should not dispatch the request" do
          VCAP::CloudController::SecurityContext.stub(:current_user) { false }
          subject.should_not_receive(:to_s)
          logger.should_not_receive(:error)
          subject.dispatch(:to_s) rescue nil
        end
      end
    end

    context "when the dispatch raises an error" do
      it "should log an error for a Sequel Validation error" do
        subject.stub(:to_s).and_raise(Sequel::ValidationFailed.new("hello"))
        VCAP::CloudController::RestController::Base.should_receive(:translate_validation_exception) { RuntimeError.new("some new error") }
        expect {
          subject.dispatch(:to_s)
        }.to raise_error RuntimeError, "some new error"
      end

      it "should reraise any vcap error" do
        error_class = Class.new(VCAP::Errors::Error)
        subject.stub(:to_s).and_raise(error_class.new(423, 10234, "Foo"))
        expect {
          subject.dispatch(:to_s)
        }.to raise_error error_class
      end

      it "should log an error for a Sequel Database Error error" do
        subject.stub(:to_s).and_raise(Sequel::DatabaseError)
        VCAP::CloudController::RestController::Base.should_receive(:translate_and_log_exception) { RuntimeError.new("some new error") }
        expect {
          subject.dispatch(:to_s)
        }.to raise_error RuntimeError, "some new error"
      end

      it "should log an error for a JSON error" do
        subject.stub(:to_s).and_raise(JsonMessage::Error)
        expect {
          subject.dispatch(:to_s)
        }.to raise_error VCAP::Errors::MessageParseError
      end

      it "should log an error for a Model error" do
        subject.stub(:to_s).and_raise(VCAP::CloudController::Models::InvalidRelation)
        expect {
          subject.dispatch(:to_s)
        }.to raise_error VCAP::Errors::InvalidRelation
      end

      it "should log for a generic exception" do
        subject.stub(:to_s).and_raise(RuntimeError.new("message"))
        expect {
          logger.should_receive(:error).with(/message/)
          subject.dispatch(:to_s)
        }.to raise_exception VCAP::Errors::ServerError
      end

      describe '#redirect' do
        let(:sinatra) { double('sinatra') }
        let(:app) do
          described_class.new(
            double(:config),
            logger, double(:env), double(:params, :[] => nil),
            double(:body),
            sinatra,
          )
        end

        it 'delegates #redirect to the injected sinatra' do
          sinatra.should_receive(:redirect).with('redirect_url')
          app.redirect('redirect_url')
        end
      end
    end
  end
end
