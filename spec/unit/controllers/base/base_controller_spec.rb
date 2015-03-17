require 'spec_helper'

module VCAP::CloudController
  describe RestController::BaseController do
    let(:logger) { double(:logger, debug: nil, error: nil) }
    let(:params) { {} }
    let(:env) { {} }
    let(:sinatra) { nil }

    class TestController < RestController::BaseController
      def test_endpoint
        'test_response'
      end
      define_route :get, '/test_endpoint', :test_endpoint

      def test_i18n
        "#{I18n.locale}"
      end
      define_route :get, '/test_i18n', :test_i18n

      def test_validation_error
        raise Sequel::ValidationFailed.new('error')
      end
      define_route :get, '/test_validation_error', :test_validation_error

      def test_sql_hook_failed
        raise Sequel::HookFailed.new('error')
      end
      define_route :get, '/test_sql_hook_failed', :test_sql_hook_failed

      def test_database_error
        raise Sequel::DatabaseError.new('error')
      end
      define_route :get, '/test_database_error', :test_database_error

      def test_json_error
        raise JsonMessage::Error.new('error')
      end
      define_route :get, '/test_json_error', :test_json_error

      def test_invalid_relation_error
        raise VCAP::Errors::InvalidRelation.new('error')
      end
      define_route :get, '/test_invalid_relation_error', :test_invalid_relation_error

      allow_unauthenticated_access only: :test_unauthenticated
      def test_unauthenticated
        'unauthenticated_response'
      end
      define_route :get, '/test_unauthenticated', :test_unauthenticated

      authenticate_basic_auth('/test_basic_auth') do
        ['username', 'password']
      end
      def test_basic_auth
        'basic_auth_response'
      end
      define_route :get, '/test_basic_auth', :test_basic_auth

      def test_warnings
        add_warning('warning1')
        add_warning('!@#$%^&*(),:|{}+=-<>')
      end
      define_route :get, '/test_warnings', :test_warnings

      def self.translate_validation_exception(error, attrs)
        RuntimeError.new('validation failed')
      end
    end

    let(:user) { User.make }

    before do
      allow_any_instance_of(TestController).to receive(:logger).and_return(logger)
    end

    describe '#dispatch' do
      context 'when the dispatch is successful' do
        let(:token_decoder) { double(:decoder) }
        let(:header_token) { 'some token' }
        let(:token_info) { { 'user_id' => 'some user' } }

        it 'should dispatch the request' do
          get '/test_endpoint', '', headers_for(user)
          expect(last_response.body).to eq 'test_response'
        end

        it 'should log a debug message' do
          expect(logger).to receive(:debug).with('cc.dispatch', endpoint: :test_endpoint, args: [])
          get '/test_endpoint', '', headers_for(user)
        end
      end

      context 'when the dispatch raises an error' do
        it 'processes Sequel Validation errors using translate_validation_exception' do
          get '/test_validation_error', '', headers_for(user)
          expect(decoded_response['description']).to eq 'validation failed'
        end

        it 'returns InvalidRequest when Sequel HookFailed error occurs' do
          get '/test_sql_hook_failed', '', headers_for(user)
          expect(decoded_response['code']).to eq 10004
        end

        it 'logs the error when a Sequel Database Error occurs' do
          expect(logger).to receive(:warn).with(/exception not translated/)
          get '/test_database_error', '', headers_for(user)
          expect(decoded_response['code']).to eq 10004
        end

        it 'logs an error when a JSON error occurs' do
          expect(logger).to receive(:debug).with(/Rescued JsonMessage::Error/)
          get '/test_json_error', '', headers_for(user)
          expect(decoded_response['code']).to eq 1001
        end

        it 'returns InvalidRelation when an Invalid Relation error occurs' do
          get '/test_invalid_relation_error', '', headers_for(user)
          expect(decoded_response['code']).to eq 1002
        end
      end

      describe '#redirect' do
        let(:request) { double('request', query_string: '') }
        let(:sinatra) { double('sinatra', request: request) }
        let(:app) do
          described_class.new(
            double(:config),
            logger, double(:env), double(:params, :[] => nil),
            double(:body),
            sinatra,
          )
        end

        it 'delegates #redirect to the injected sinatra' do
          expect(sinatra).to receive(:redirect).with('redirect_url')
          app.redirect('redirect_url')
        end
      end

      describe 'internationalization' do
        it 'should record the locale during dispatching the request' do
          get '/test_i18n', '', headers_for(user).merge({ 'HTTP_ACCEPT_LANGUAGE' => 'never_Neverland' })
          expect(last_response.body).to eq('never_Neverland')
        end
      end

      describe 'authentication' do
        context 'when the token contains a valid user' do
          let(:headers) { headers_for(user) }
          it 'allows the operation' do
            get '/test_endpoint', '', headers
            expect(last_response.body).to eq 'test_response'
          end

          context 'and the endpoint allows authenticated access' do
            it 'allows the operation' do
              get '/test_unauthenticated', '', headers
              expect(last_response.body).to eq 'unauthenticated_response'
            end
          end
        end

        context 'when there is no token' do
          it 'returns NotAuthenticated' do
            get '/test_endpoint'
            expect(last_response.status).to eq 401
            expect(decoded_response['code']).to eq 10002
          end

          context 'when a particular operation is allowed to skip authentication' do
            it 'does not raise error' do
              get '/test_unauthenticated'
              expect(last_response.body).to eq 'unauthenticated_response'
            end
          end
        end

        context 'when the token cannot be parsed' do
          it 'returns InvalidAuthToken' do
            get '/test_endpoint', '', 'HTTP_AUTHORIZATION' => 'BEARER fake_token'
            expect(decoded_response['code']).to eq 1000
            expect(last_response.status).to eq 401
          end
        end

        context 'when the endpoint requires basic auth' do
          it 'returns NotAuthenticated if username and password are not provided' do
            get '/test_basic_auth'
            expect(decoded_response['code']).to eq 10002
          end

          it 'returns NotAuthenticated if username and password are wrong' do
            authorize 'username', 'letmein'
            get '/test_basic_auth'
            expect(decoded_response['code']).to eq 10002
          end

          it 'does not raise NotAuthorized if username and password is correct' do
            authorize 'username', 'password'

            get '/test_basic_auth'
            expect(last_response.body).to_not eq 'basic_auth_response'
          end
        end
      end
    end

    describe '#recursive?' do
      subject(:base_controller) do
        VCAP::CloudController::RestController::BaseController.new(double(:config), logger, env, params, double(:body), nil)
      end

      context 'when the recursive flag is present' do
        context 'and the flag is true' do
          let(:params) { { 'recursive' => 'true' } }
          it { is_expected.to be_recursive }
        end

        context 'and the flag is false' do
          let(:params) { { 'recursive' => 'false' } }
          it { is_expected.not_to be_recursive }
        end
      end

      context 'when the recursive flag is not present' do
        it { is_expected.not_to be_recursive }
      end
    end

    describe '#v2_api?' do
      subject(:base_controller) do
        VCAP::CloudController::RestController::BaseController.new(double(:config), logger, env, params, double(:body), nil)
      end
      context 'when the endpoint is v2' do
        let(:env) { { 'PATH_INFO' => '/v2/foobar' } }
        it { is_expected.to be_v2_api }
      end

      context 'when the endpoint is not v2' do
        let(:env) { { 'PATH_INFO' => '/v1/foobar' } }
        it { is_expected.not_to be_v2_api }

        context 'and the v2 is in capitals' do
          let(:env) { { 'PATH_INFO' => '/V2/foobar' } }
          it { is_expected.not_to be_v2_api }
        end

        context 'and the v2 is somewhere in the middle (for example, the app is called v2)' do
          let(:env) { { 'PATH_INFO' => '/v1/apps/v2' } }
          it { is_expected.not_to be_v2_api }
        end
      end
    end

    describe '#async?' do
      subject(:base_controller) do
        VCAP::CloudController::RestController::BaseController.new(double(:config), logger, env, params, double(:body), nil)
      end
      context 'when the async flag is present' do
        context 'and the flag is true' do
          let(:params) { { 'async' => 'true' } }
          it { is_expected.to be_async }
        end

        context 'and the flag is false' do
          let(:params) { { 'async' => 'false' } }
          it { is_expected.not_to be_async }
        end
      end

      context 'when the async flag is not present' do
        it { is_expected.not_to be_async }
      end
    end

    describe '#add_warning' do
      it 'sets warnings in the X-Cf-Warnings header' do
        get '/test_warnings', '', headers_for(user)

        warnings_header = last_response.headers['X-Cf-Warnings']
        warnings = warnings_header.split(',')

        expect(CGI.unescape(warnings[0])).to eq('warning1')
        expect(CGI.unescape(warnings[1])).to eq('!@#$%^&*(),:|{}+=-<>')
      end
    end

    describe '#check_read_permissions!' do
      subject(:base_controller) do
        VCAP::CloudController::RestController::BaseController.new(double(:config), logger, env, params, double(:body), nil)
      end

      before do
        allow(SecurityContext).to receive(:roles).and_return(double(:roles, admin?: false))
        allow(SecurityContext).to receive(:scopes).and_return([])
      end

      context 'when the user is an admin' do
        before do
          allow(SecurityContext).to receive(:roles).and_return(double(:roles, admin?: true))
        end

        it 'does not raise an error' do
          expect {
            base_controller.check_read_permissions!
          }.not_to raise_error
        end
      end

      context 'when user has read scope' do
        before do
          allow(SecurityContext).to receive(:scopes).and_return(['cloud_controller.read'])
        end

        it 'does not raise an error' do
          expect {
            base_controller.check_read_permissions!
          }.not_to raise_error
        end
      end

      context 'when user does not have read scope' do
        it 'raises an unauthorized API error' do
          expect {
            base_controller.check_read_permissions!
          }.to raise_error VCAP::Errors::ApiError
        end
      end
    end

    describe '#check_write_permissions!' do
      subject(:base_controller) do
        VCAP::CloudController::RestController::BaseController.new(double(:config), logger, env, params, double(:body), nil)
      end

      before do
        allow(SecurityContext).to receive(:roles).and_return(double(:roles, admin?: false))
        allow(SecurityContext).to receive(:scopes).and_return([])
      end

      context 'when the user is an admin' do
        before do
          allow(SecurityContext).to receive(:roles).and_return(double(:roles, admin?: true))
        end

        it 'does not raise an error' do
          expect {
            base_controller.check_write_permissions!
          }.not_to raise_error
        end
      end

      context 'when user has write scope' do
        before do
          allow(SecurityContext).to receive(:scopes).and_return(['cloud_controller.write'])
        end

        it 'does not raise an error' do
          expect {
            base_controller.check_write_permissions!
          }.not_to raise_error
        end
      end

      context 'when user does not have write scope' do
        it 'raises an unauthorized API error' do
          expect {
            base_controller.check_write_permissions!
          }.to raise_error VCAP::Errors::ApiError
        end
      end
    end
  end
end
