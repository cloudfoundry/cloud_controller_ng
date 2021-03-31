require 'spec_helper'
require 'security_context_setter'

module CloudFoundry
  module Middleware
    RSpec.describe SecurityContextSetter do
      let(:middleware) { SecurityContextSetter.new(app, security_context_configurer) }
      let(:app) { double(:app, call: [200, {}, 'a body']) }
      let(:path_info) { '/v2/foo' }
      let(:env) do
        {
          'HTTP_AUTHORIZATION' => 'auth-token',
          'PATH_INFO' => path_info,
        }
      end
      let(:token_decoder) { instance_double(VCAP::CloudController::UaaTokenDecoder) }
      let(:security_context_configurer) { VCAP::CloudController::Security::SecurityContextConfigurer.new(token_decoder) }

      describe '#call' do
        let(:token_information) { { 'user_id' => 'user-id-1', 'user_name' => 'mrpotato' } }

        before do
          allow(token_decoder).to receive(:decode_token).with('auth-token').and_return(token_information)
        end

        it 'sets the security context token and the raw token' do
          middleware.call(env)
          expect(VCAP::CloudController::SecurityContext.token).to eq(token_information)
          expect(VCAP::CloudController::SecurityContext.auth_token).to eq('auth-token')
        end

        it 'adds the X-USER-GUID header' do
          _, header, _ = middleware.call(env)
          expect(header).to eq({ 'X-USER-GUID' => 'user-id-1' })
        end

        context 'when given a UAA user token' do
          it 'sets user name and guid on the env' do
            middleware.call(env)

            expect(app).to have_received(:call) do |passed_env|
              expect(passed_env['cf.user_guid']).to eq('user-id-1')
              expect(passed_env['cf.user_name']).to eq('mrpotato')
            end
          end
        end

        context 'when given a UAA client token' do
          let(:token_information) { { 'client_id' => 'client-id-1', 'user_name' => 'mrpotato' } }

          it 'sets client id as the user guid on the env' do
            middleware.call(env)

            expect(app).to have_received(:call) do |passed_env|
              expect(passed_env['cf.user_guid']).to eq('client-id-1')
              expect(passed_env['cf.user_name']).to eq('mrpotato')
            end
          end
        end

        context 'when there is no token (unauthenticated)' do
          before do
            allow(token_decoder).to receive(:decode_token)
          end

          it 'does not set the X-USER-GUID header' do
            _, header, _ = middleware.call({})
            expect(header).not_to include('X-USER-GUID')
          end
        end

        context 'when the rate limiter returns 429' do
          let(:app) { double(:app, call: [429, { 'X-RateLimit-Remaining' => '0' }, 'a body']) }

          context 'when token is valid' do
            before do
              allow(VCAP::CloudController::SecurityContext).to receive(:valid_token?).and_return(true)
            end

            it 'forwards the response from the rate limiter' do
              status, headers, body = middleware.call(env)
              expect(status).to eq(429)
              expect(headers).to include({ 'X-RateLimit-Remaining' => '0' })
              expect(body).to eq('a body')
            end
          end
          context 'when token is invalid' do
            before do
              allow(VCAP::CloudController::SecurityContext).to receive(:valid_token?).and_return(false)
              allow(VCAP::CloudController::SecurityContext).to receive(:missing_token?).and_return(false)
            end

            it 'changes the response to 401' do
              status, headers, body = middleware.call(env)
              expect(status).to eq(401)
              expect(headers).to eq({ 'Content-Length' => '189', 'Content-Type' => 'application/json', 'X-RateLimit-Remaining' => '0' })
              json_body = JSON.parse(body.first)
              expect(json_body).to include(
                'code' => 1000,
                'description' => 'Invalid Auth Token',
                'error_code' => 'CF-InvalidAuthToken',
              )
            end
          end
          context 'when token is missing' do
            before do
              allow(VCAP::CloudController::SecurityContext).to receive(:valid_token?).and_return(false)
              allow(VCAP::CloudController::SecurityContext).to receive(:missing_token?).and_return(true)
            end

            it 'forwards the response from the rate limiter' do
              status, headers, body = middleware.call(env)
              expect(status).to eq(429)
              expect(headers).to eq({ 'X-RateLimit-Remaining' => '0' })
              expect(body).to eq('a body')
            end
          end
        end

        context 'when Uaa is unavailable' do
          before do
            allow(VCAP::CloudController::SecurityContext).to receive(:valid_token?).and_raise(VCAP::CloudController::UaaUnavailable)
          end

          it 'returns a 502' do
            status, _, _ = middleware.call(env)
            expect(status).to eq(502)
          end

          context 'when the path is /v2/*' do
            it 'throws an error' do
              _, _, body = middleware.call(env)
              json_body = JSON.parse(body.first)
              expect(json_body).to include(
                'code' => 20004,
                'description' => 'The UAA service is currently unavailable',
                'error_code' => 'CF-UaaUnavailable',
              )
            end
          end

          context 'when the path is /v3/*' do
            let(:path_info) { '/v3/foo' }
            it 'throws an error' do
              _, _, body = middleware.call(env)
              json_body = JSON.parse(body.first)
              expect(json_body['errors'].first).to include(
                'code' => 20004,
                'detail' => 'The UAA service is currently unavailable',
                'title' => 'CF-UaaUnavailable',
              )
            end
          end
        end
      end
    end
  end
end
