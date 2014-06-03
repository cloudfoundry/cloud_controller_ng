require "spec_helper"

describe VCAP::CloudController::RestController::Base, type: :controller do
  let(:logger) { double(:logger, :debug => nil, :error => nil) }
  let(:env) { {} }
  let(:params) { {} }
  let(:sinatra) { nil }

  subject do
    VCAP::CloudController::RestController::Base.new(double(:config), logger, env, params, double(:body), sinatra)
  end

  describe "#dispatch" do
    context "when the dispatch is succesful" do
      let(:token_decoder) { double(:decoder) }
      let(:header_token) { 'some token' }
      let(:token_info) { {'user_id' => 'some user'} }

      before do
        configurer = VCAP::CloudController::Security::SecurityContextConfigurer.new(token_decoder)
        allow(token_decoder).to receive(:decode_token).with(header_token).and_return(token_info)
        configurer.configure(header_token)
      end

      it "should dispatch the request" do
        subject.should_receive(:to_s).with([:a, :b])
        subject.dispatch(:to_s, [:a, :b])
      end

      it "should log a debug message" do
        logger.should_receive(:debug).with("cc.dispatch", endpoint: :to_s, args: [])
        subject.dispatch(:to_s)
      end

      context "when there is no current user" do
        let(:token_info) { nil }

        it "should not dispatch the request" do
          subject.should_not_receive(:to_s)
          logger.should_not_receive(:error)
          subject.dispatch(:to_s) rescue nil
        end
      end
    end

    context "when the dispatch raises an error" do
      let(:token_decoder) { double(:decoder) }
      let(:header_token) { 'some token' }
      let(:token_info) { {'user_id' => 'some user'} }

      before do
        configurer = VCAP::CloudController::Security::SecurityContextConfigurer.new(token_decoder)
        allow(token_decoder).to receive(:decode_token).with(header_token).and_return(token_info)
        configurer.configure(header_token)
      end

      it "should log an error for a Sequel Validation error" do
        subject.stub(:to_s).and_raise(Sequel::ValidationFailed.new("hello"))
        VCAP::CloudController::RestController::Base.should_receive(:translate_validation_exception) { RuntimeError.new("some new error") }
        expect {
          subject.dispatch(:to_s)
        }.to raise_error RuntimeError, "some new error"
      end

      it "should log an error for a Sequel HookFailed error" do
        subject.stub(:to_s).and_raise(Sequel::HookFailed.new("hello"))
        expect {
          subject.dispatch(:to_s)
        }.to raise_error VCAP::Errors::ApiError
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

    describe 'authentication' do
      let(:token_decoder) { double(:decoder) }
      let(:header_token) { 'some token' }

      context 'when the token contains a valid user' do
        let(:token_info) { {'user_id' => 'some user'} }

        before do
          configurer = VCAP::CloudController::Security::SecurityContextConfigurer.new(token_decoder)
          allow(token_decoder).to receive(:decode_token).with(header_token).and_return(token_info)
          configurer.configure(header_token)
        end

        it 'allows the operation' do
          subject.stub(:download)

          subject.dispatch(:download)
          expect(subject).to have_received(:download)
        end
      end

      context 'when the token has no user but contains an admin scope' do
        let(:token_info) { { 'scope' => ['cloud_controller.admin'] } }

        before do
          configurer = VCAP::CloudController::Security::SecurityContextConfigurer.new(token_decoder)
          allow(token_decoder).to receive(:decode_token).with(header_token).and_return(token_info)
          configurer.configure(header_token)
        end

        it 'allows the operation' do
          subject.stub(:download)

          subject.dispatch(:download)
          expect(subject).to have_received(:download)
        end
      end

      context 'when there is no token' do
        let(:token_info) { nil }

        before do
          configurer = VCAP::CloudController::Security::SecurityContextConfigurer.new(token_decoder)
          allow(token_decoder).to receive(:decode_token).with(header_token).and_return(token_info)
          configurer.configure(header_token)
        end

        it 'raises a NotAuthenticated error' do
          subject.stub(:download)

          expect {
            subject.dispatch(:download)
          }.to raise_error VCAP::Errors::ApiError, /Authentication error/
        end

        context 'when a particular operation is allowed to skip authentication' do
          before do
            subject.stub(:unauthed_download)
            subject.class.allow_unauthenticated_access(:only => :unauthed_download)
          end

          it 'does not raise error' do
            expect { subject.dispatch(:unauthed_download) }.to_not raise_error
          end

          it 'raise error when dispatching a operation not allowed' do
            expect { subject.dispatch(:download) }.to raise_error(VCAP::Errors::ApiError)
          end
        end

        context 'when all operations on the controller are allowed to skip authentication' do
          before do
            subject.stub(:download)
            subject.class.allow_unauthenticated_access
          end

          after do
            subject.class.instance_variable_set(:@allow_unauthenticated_access_to_all_ops, nil)
          end

          it 'does not raise error' do
            expect { subject.dispatch(:download) }.to_not raise_error
          end
        end
      end

      context 'when the token cannot be parsed' do
        before do
          configurer = VCAP::CloudController::Security::SecurityContextConfigurer.new(token_decoder)
          allow(token_decoder).to receive(:decode_token).with(header_token).and_raise(VCAP::UaaTokenDecoder::BadToken)
          configurer.configure(header_token)
        end

        it 'raises InvalidAuthToken' do
          subject.stub(:download)

          expect {
            subject.dispatch(:download)
          }.to raise_error VCAP::Errors::ApiError, /Invalid Auth Token/
        end
      end

      context 'when the endpoint requires basic auth' do
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

      context 'when there is no user, no admin scope, with a token that is not invalid' do
        # With a properly functioning UAA, we expect this case to be impossible. Nevertheless,
        # we wan to be defensive because failing to handle this case would allow unauthenticated
        # access to CC resources.
        let(:token_info) { {'scope' => ['some-non-admin-scope'] } }

        before do
          configurer = VCAP::CloudController::Security::SecurityContextConfigurer.new(token_decoder)
          allow(token_decoder).to receive(:decode_token).with(header_token).and_return(token_info)
          configurer.configure(header_token)
        end

        it 'logs an error message because this error is unexpected' do
          logger = double(:logger, error: nil, debug: nil)
          allow(subject).to receive(:logger).and_return(logger)

          subject.dispatch(:download) rescue nil

          expect(logger).to have_received(:error).with('Unexpected condition: valid token with no user/client id or admin scope. Token hash: {"scope"=>["some-non-admin-scope"]}')
        end

        it 'raises an InvalidAuthToken error' do
          subject.stub(:download)

          expect {
            subject.dispatch(:download)
          }.to raise_error VCAP::Errors::ApiError, /Invalid Auth Token/
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

  describe "#add_warning" do
    let(:expected_key) { 'X-Cf-Warnings' }
    let(:sinatra) { double(:sinatra) }
    let(:header_hash) { {} }

    before do
      allow(sinatra).to receive(:headers).and_return(header_hash)
    end

    it 'sets the X-Cf-Warnings header' do
      subject.add_warning('warning')

      expect(header_hash[expected_key]).to eq('warning')
    end

    it 'comma separates multiple warnings' do
      subject.add_warning('warning1')
      subject.add_warning('warning2')

      expect(header_hash[expected_key]).to eq('warning1,warning2')
    end

    it 'rfc3986 escapes the warnings' do
      special_chars_warning = '!@#$%^&*(),:|{}+=-<>'

      subject.add_warning('first, warning')
      subject.add_warning(special_chars_warning)
      subject.add_warning('last: warning!')

      warnings = header_hash[expected_key].split(',')

      expect(CGI.unescape(warnings[0])).to eq('first, warning')
      expect(CGI.unescape(warnings[1])).to eq(special_chars_warning)
      expect(CGI.unescape(warnings[2])).to eq('last: warning!')
    end
  end
end
