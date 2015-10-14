require 'spec_helper'

module VCAP::CloudController
  describe FrontController do
    let(:fake_logger) { double(Steno::Logger, info: nil) }
    let(:request_metrics) { double(:request_metrics, start_request: nil, complete_request: nil) }

    before :all do
      FrontController.get '/test_front_endpoint' do
        'test'
      end

      FrontController.options '/test_front_endpoint' do
        status 201
        'options'
      end
    end

    describe 'setting the locale' do
      before do
        @original_default_locale = I18n.default_locale
        @original_locale         = I18n.locale

        I18n.default_locale = :metropolis
        I18n.locale         = :metropolis
      end

      after do
        I18n.default_locale = @original_default_locale
        I18n.locale         = @original_locale
      end

      context 'When the Accept-Language header is set' do
        it 'sets the locale based on the Accept-Language header' do
          get '/test_front_endpoint', '', { 'HTTP_ACCEPT_LANGUAGE' => 'gotham_City' }
          expect(I18n.locale).to eq(:gotham_City)
        end
      end

      context 'when the Accept-Language header is not set' do
        it 'maintains the default locale' do
          get '/test_front_endpoint', '', {}
          expect(I18n.locale).to eq(:metropolis)
        end
      end
    end

    describe 'logging' do
      let(:app) { described_class.new({ https_required: true }, token_decoder, request_metrics) }
      let(:token_decoder) { double(:token_decoder, decode_token: { 'user_id' => 'fake-user-id' }) }

      context 'get request' do
        before do
          allow(Steno).to receive(:logger).with(anything).and_return(fake_logger)
        end

        it 'logs request id and status code for all requests' do
          get '/test_front_endpoint', '', {}
          request_id = last_response.headers['X-Vcap-Request-Id']
          request_status = last_response.status.to_s
          expect(fake_logger).to have_received(:info).with("Completed request, Vcap-Request-Id: #{request_id}, Status: #{request_status}")
        end

        it 'logs request id and user guid for all requests' do
          get '/test_front_endpoint', '', {}
          request_id = last_response.headers['X-Vcap-Request-Id']
          expect(fake_logger).to have_received(:info).with("Started request, Vcap-Request-Id: #{request_id}, User: fake-user-id")
        end
      end
    end

    describe 'validating the auth token' do
      let(:user_id) { Sham.guid }
      let(:token_info) { {} }

      let(:config) do
        {
          quota_definitions: [],
          uaa: { resource_id: 'cloud_controller' }
        }
      end
      let(:token_decoder) do
        token_decoder = VCAP::UaaTokenDecoder.new(config[:uaa])
        allow(token_decoder).to receive_messages(decode_token: token_info)
        token_decoder
      end

      def app
        described_class.new(TestConfig.config, token_decoder, request_metrics)
      end

      def make_request
        get '/test_front_endpoint', '', { 'HTTP_AUTHORIZATION' => 'bearer token' }
      end

      context 'when user_id is present' do
        before { token_info['user_id'] = user_id }

        it 'creates a user' do
          expect {
            make_request
          }.to change { VCAP::CloudController::User.count }.by(1)

          user = VCAP::CloudController::User.last
          expect(user.guid).to eq(user_id)
          expect(user.active).to be true
        end

        it 'sets security context to the user' do
          make_request
          expect(VCAP::CloudController::SecurityContext.current_user).to eq VCAP::CloudController::User.last
          expect(VCAP::CloudController::SecurityContext.token['user_id']).to eq user_id
        end
      end

      context 'when client_id is present' do
        before { token_info['client_id'] = user_id }

        it 'creates a user' do
          expect {
            make_request
          }.to change { VCAP::CloudController::User.count }.by(1)

          user = VCAP::CloudController::User.last
          expect(user.guid).to eq(user_id)
          expect(user.active).to be true
        end

        it 'sets security context to the user' do
          make_request
          expect(VCAP::CloudController::SecurityContext.current_user).to eq VCAP::CloudController::User.last
          expect(VCAP::CloudController::SecurityContext.token['client_id']).to eq user_id
        end
      end

      context 'when there is no user_id or client_id' do
        it 'does not create user' do
          expect { make_request }.to_not change { VCAP::CloudController::User.count }
        end

        it 'sets security context to be empty' do
          make_request
          expect(VCAP::CloudController::SecurityContext.current_user).to be_nil
          expect(VCAP::CloudController::SecurityContext.token).to be_nil
        end
      end
    end

    describe 'request metrics' do
      let(:app) { described_class.new(nil, token_decoder, request_metrics) }
      let(:token_decoder) { VCAP::UaaTokenDecoder.new({}) }

      before do
        allow(token_decoder).to receive_messages(decode_token: {})
      end

      it 'triggers metrics' do
        get '/test_front_endpoint', '', {}

        expect(request_metrics).to have_received(:start_request)
        expect(request_metrics).to have_received(:complete_request).with(200)
      end
    end
  end
end
