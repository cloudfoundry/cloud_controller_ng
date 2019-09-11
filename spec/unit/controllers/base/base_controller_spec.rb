require 'spec_helper'

module VCAP::CloudController
  RSpec.describe RestController::BaseController do
    let(:logger) { double(:logger, debug: nil, error: nil) }
    let(:params) { {} }
    let(:env) { {} }
    let(:sinatra) { nil }
    let(:config) { double(Config, get: nil) }
    let(:dependencies) do
      {
        statsd_client: double(Statsd),
        perm_client: double(Perm::Client),
      }
    end

    class TestController < RestController::BaseController
      allow_unauthenticated_access only: [:test_unauthenticated, :test_basic_auth]

      def test_endpoint
        'test_response'
      end
      define_route :get, '/test_endpoint', :test_endpoint

      def test_validation_error
        raise Sequel::ValidationFailed.new('error')
      end
      define_route :get, '/test_validation_error', :test_validation_error

      def test_sql_hook_failed
        raise Sequel::HookFailed.new('error')
      end
      define_route :get, '/test_sql_hook_failed', :test_sql_hook_failed

      def test_blobstore_error
        raise CloudController::Blobstore::BlobstoreError.new('whoops!')
      end
      define_route :get, '/test_blobstore_error', :test_blobstore_error

      def test_database_error
        raise Sequel::DatabaseError.new('error')
      end
      define_route :get, '/test_database_error', :test_database_error

      def test_json_error
        raise JsonMessage::Error.new('error')
      end
      define_route :get, '/test_json_error', :test_json_error

      def test_invalid_relation_error
        raise CloudController::Errors::InvalidRelation.new('error')
      end
      define_route :get, '/test_invalid_relation_error', :test_invalid_relation_error

      def test_unauthenticated
        'unauthenticated_response'
      end
      define_route :get, '/test_unauthenticated', :test_unauthenticated

      authenticate_basic_auth('/test_basic_auth') do
        ['username', "p'a\"ss%40%3A%3Fwo!r%24d"]
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
        before { set_current_user(user) }

        it 'should dispatch the request' do
          get '/test_endpoint'
          expect(last_response.body).to eq 'test_response'
        end

        it 'should log a debug message' do
          expect(logger).to receive(:debug).with('cc.dispatch', endpoint: :test_endpoint, args: [])
          get '/test_endpoint'
        end
      end

      context 'when the dispatch raises an error' do
        before do
          allow_any_instance_of(ErrorPresenter).to receive(:raise_500?).and_return(false)
          set_current_user(user)
        end

        it 'processes Sequel Validation errors using translate_validation_exception' do
          get '/test_validation_error'
          expect(decoded_response['description']).to eq('An unknown error occurred.')
        end

        it 'processes BlobstoreError using translate_validation_exception' do
          get '/test_blobstore_error'
          expect(decoded_response['code']).to eq(150007)
          expect(decoded_response['description']).to match(/three retries/)
        end

        it 'returns InvalidRequest when Sequel HookFailed error occurs' do
          get '/test_sql_hook_failed'
          expect(decoded_response['code']).to eq(10004)
        end

        it 'logs the error when a Sequel Database Error occurs' do
          expect(logger).to receive(:warn).with(/exception not translated/)
          get '/test_database_error'
          expect(decoded_response['code']).to eq(10011)
        end

        it 'logs an error when a JSON error occurs' do
          expect(logger).to receive(:debug).with(/Rescued JsonMessage::Error/)
          get '/test_json_error'
          expect(decoded_response['code']).to eq(1001)
        end

        it 'returns InvalidRelation when an Invalid Relation error occurs' do
          get '/test_invalid_relation_error'
          expect(decoded_response['code']).to eq(1002)
        end
      end

      describe '#redirect' do
        let(:request) { double('request', query_string: '') }
        let(:sinatra) { double('sinatra', request: request) }
        let(:env) { double(:env) }
        let(:app) do
          RestController::BaseController.new(
            config,
            logger, env, double(:params, :[] => nil),
            double(:body),
            sinatra,
            dependencies
          )
        end

        before do
          allow(env).to receive(:[])
        end

        it 'delegates #redirect to the injected sinatra' do
          expect(sinatra).to receive(:redirect).with('redirect_url')
          app.redirect('redirect_url')
        end
      end

      describe 'authentication' do
        context 'when there is no current user' do
          before { set_current_user(nil) }

          context 'when a particular operation is allowed to skip authentication' do
            it 'does not raise error' do
              get '/test_unauthenticated'
              expect(last_response.body).to eq 'unauthenticated_response'
            end
          end

          context 'when the token is invalid/ expired' do
            before do
              VCAP::CloudController::SecurityContext.set(nil, :invalid_token, nil)
            end

            it 'returns an invalid token error to the user' do
              get '/test_endpoint'
              expect(last_response.status).to eq 401
              expect(last_response.body).to match /InvalidAuthToken/
            end
          end
        end

        context 'when the endpoint requires basic auth' do
          let(:unencoded_password) { "p'a\"ss@:?wo!r$d" }
          let(:encoded_password) { CGI.escape(unencoded_password) }

          it 'this is just a check around our encoding and decoding assumptions' do
            expect(CGI.unescape(encoded_password)).to eq(unencoded_password)
          end

          it 'returns NotAuthenticated if username and password are not provided' do
            get '/test_basic_auth'
            expect(last_response.status).to eq 401
            expect(decoded_response['code']).to eq 10002
          end

          it 'returns NotAuthenticated if username and password are wrong' do
            authorize 'username', 'letmein'

            get '/test_basic_auth'
            expect(last_response.status).to eq 401
            expect(decoded_response['code']).to eq 10002
          end

          context 'when diego returns percent-decoded staging credentials' do
            it 'successfully authenticates' do
              authorize 'username', unencoded_password

              get '/test_basic_auth'
              expect(last_response.status).to eq 200
              expect(last_response.body).to eq 'basic_auth_response'
            end
          end
        end
      end
    end

    describe '#recursive_delete?' do
      subject(:base_controller) do
        VCAP::CloudController::RestController::BaseController.new(config, logger, env, params, double(:body), nil, dependencies)
      end

      context 'when the recursive flag is present' do
        context 'and the flag is true' do
          let(:params) { { 'recursive' => 'true' } }
          it { is_expected.to be_recursive_delete }
        end

        context 'and the flag is false' do
          let(:params) { { 'recursive' => 'false' } }
          it { is_expected.not_to be_recursive_delete }
        end
      end

      context 'when the recursive flag is not present' do
        it { is_expected.not_to be_recursive_delete }
      end
    end

    describe '#async?' do
      subject(:base_controller) do
        VCAP::CloudController::RestController::BaseController.new(config, logger, env, params, double(:body), nil, dependencies)
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

    describe '#convert_flag_to_bool' do
      let(:base_controller) do
        VCAP::CloudController::RestController::BaseController.new(config, logger, env, params, double(:body), nil, dependencies)
      end

      context 'when flag is true' do
        it 'returns true' do
          expect(base_controller.convert_flag_to_bool('true')).to eq(true)
        end
      end

      context 'when flag is false' do
        it 'returns false' do
          expect(base_controller.convert_flag_to_bool('false')).to eq(false)
        end
      end

      context 'when flag is nil' do
        it 'returns false' do
          expect(base_controller.convert_flag_to_bool(nil)).to eq(false)
        end
      end

      context 'when flag is not a bool' do
        it 'raises a 400 error' do
          expect {
            base_controller.convert_flag_to_bool('foo')
          }.to raise_error(CloudController::Errors::ApiError, 'The request is invalid')
        end
      end
    end

    describe '#add_warning' do
      it 'sets warnings in the X-Cf-Warnings header' do
        set_current_user(user)
        get '/test_warnings'

        warnings_header = last_response.headers['X-Cf-Warnings']
        warnings = warnings_header.split(',')

        expect(CGI.unescape(warnings[0])).to eq('warning1')
        expect(CGI.unescape(warnings[1])).to eq('!@#$%^&*(),:|{}+=-<>')
      end
    end

    describe '#check_read_permissions!' do
      subject(:base_controller) do
        VCAP::CloudController::RestController::BaseController.new(config, logger, env, params, double(:body), nil, dependencies)
      end

      before do
        allow(SecurityContext).to receive(:roles).and_return(double(:roles, admin?: false, admin_read_only?: false, global_auditor?: false))
        allow(SecurityContext).to receive(:scopes).and_return([])
      end

      context 'when the user is an admin' do
        before do
          allow(SecurityContext).to receive(:roles).and_return(double(:roles, admin?: true, admin_read_only?: false, global_auditor?: false))
        end

        it 'does not raise an error' do
          expect {
            base_controller.check_read_permissions!
          }.not_to raise_error
        end
      end

      context 'when the user is a read-only admin' do
        before do
          allow(SecurityContext).to receive(:roles).and_return(double(:roles, admin?: false, admin_read_only?: true, global_auditor?: false))
        end

        it 'does not raise an error' do
          expect {
            base_controller.check_read_permissions!
          }.not_to raise_error
        end
      end

      context 'when the user is a global auditor' do
        before do
          allow(SecurityContext).to receive(:roles).and_return(double(:roles, admin?: false, admin_read_only?: false, global_auditor?: true))
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
          }.to raise_error CloudController::Errors::ApiError
        end
      end
    end

    describe '#check_write_permissions!' do
      subject(:base_controller) do
        VCAP::CloudController::RestController::BaseController.new(config, logger, env, params, double(:body), nil, dependencies)
      end

      before do
        allow(SecurityContext).to receive(:roles).and_return(double(:roles, admin?: false, admin_read_only?: false, global_auditor?: false))
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
          }.to raise_error CloudController::Errors::ApiError
        end
      end
    end
  end
end
