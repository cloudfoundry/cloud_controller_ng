require "spec_helper"

describe VCAP::CloudController::RestController::Base, type: :controller do
  before do
    VCAP::CloudController::SecurityContext.stub(:current_user) { true }
  end

  let(:logger) { double(:logger, :debug => nil, :error => nil) }
  let(:env) { {} }
  let(:params) { {} }

  subject do
    VCAP::CloudController::RestController::Base.new(double(:config), logger, env, params, double(:body))
  end

  describe "#dispatch" do
    context "when the dispatch is succesful" do
      it "should dispatch the request" do
        subject.should_receive(:to_s).with([:a, :b])
        subject.dispatch(:to_s, [:a, :b])
      end

      it "should log a debug message" do
        logger.should_receive(:debug).with("cc.dispatch", endpoint: :to_s, args: [])
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

    context "when operation is allowed to skip authentication" do
      before do
        VCAP::CloudController::SecurityContext.stub(:current_user) { false }
        subject.stub(:download)
      end

      context "skipping an operation" do
        before do
          subject.class.allow_unauthenticated_access(:only => :download)
        end

        it "does not raise error" do
          expect { subject.dispatch(:download) }.to_not raise_error
        end

        it "raise error when dispatching a operation not allowed" do
          expect { subject.dispatch(:not_allowed_download) }.to raise_error
        end
      end

      context "when configured to skip all operations" do
        before do
          subject.class.allow_unauthenticated_access
        end

        it "does not raise error" do
          expect { subject.dispatch(:download) }.to_not raise_error
        end
      end
    end

    describe "authenticate_basic_auth" do
      it "returns NotAuthorized without if username and password was not provided" do
        subject.class.authenticate_basic_auth("/my_path") do
          ["username", "password"]
        end

        get "/my_path"
        expect(last_response.status).to eq(403)
        expect(last_response.body).to match /You are not authorized/
      end

      it "returns NotAuthorized without if username and password was wrong" do
        authorize "username", "letmein"
        subject.class.authenticate_basic_auth("/my_path") do
          ["username", "password"]
        end

        get "/my_path"
        expect(last_response.status).to eq(403)
        expect(last_response.body).to match /You are not authorized/
      end

      it "does not raise NotAuthorized if username and password is correct" do
        authorize "username", "password"

        subject.class.authenticate_basic_auth("/my_path") do
          ["username", "password"]
        end

        get "/my_path"
        expect(last_response.status).to_not eq 403
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
        subject.stub(:to_s).and_raise(VCAP::Errors::ApiError.new_from_details("NotAuthorized"))
        expect {
          subject.dispatch(:to_s)
        }.to raise_error VCAP::Errors::ApiError
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
        }.to raise_error(VCAP::Errors::ApiError, /Request invalid due to parse error/)
      end

      it "should log an error for a Model error" do
        subject.stub(:to_s).and_raise(VCAP::Errors::InvalidRelation)
        expect {
          subject.dispatch(:to_s)
        }.to raise_error(VCAP::Errors::ApiError, /Invalid relation/)
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

  describe "#recursive?" do
    context "when the recursive flag is present" do
      context "and the flag is true" do
        let(:params) { {"recursive" => "true"} }
        it { should be_recursive }
      end

      context "and the flag is false" do
        let(:params) { {"recursive" => "false"} }
        it { should_not be_recursive }
      end
    end

    context "when the recursive flag is not present" do
      it { should_not be_recursive }
    end
  end

  describe "#v2_api?" do
    context "when the endpoint is v2" do
      let(:env) { { "PATH_INFO" => "/v2/foobar" } }
      it { should be_v2_api }
    end

    context "when the endpoint is not v2" do
      let(:env) { { "PATH_INFO" => "/v1/foobar" } }
      it { should_not be_v2_api }

      context "and the v2 is in capitals" do
        let(:env) { { "PATH_INFO" => "/V2/foobar" } }
        it { should_not be_v2_api }
      end

      context "and the v2 is somewhere in the middle (for example, the app is called v2)" do
        let(:env) { { "PATH_INFO" => "/v1/apps/v2" } }
        it { should_not be_v2_api }
      end
    end
  end
  
  describe "#async?" do
    context "when the async flag is present" do
      context "and the flag is true" do
        let(:params) { {"async" => "true"} }
        it { should be_async }
      end

      context "and the flag is false" do
        let(:params) { {"async" => "false"} }
        it { should_not be_async }
      end
    end

    context "when the async flag is not present" do
      it { should_not be_async }
    end
  end
end
