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
          'PATH_INFO' => path_info
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
          _, header, = middleware.call(env)
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

          it 'sets the user guid on the request and deletes it afterwards' do
            expect(::VCAP::Request).to receive(:user_guid=).with('user-id-1')
            expect(::VCAP::Request).to receive(:user_guid=).with(nil)
            middleware.call(env)
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

          it 'sets the client id as the user guid on the request and deletes it afterwards' do
            expect(::VCAP::Request).to receive(:user_guid=).with('client-id-1')
            expect(::VCAP::Request).to receive(:user_guid=).with(nil)

            middleware.call(env)
          end
        end

        context 'when there is no token (unauthenticated)' do
          before do
            allow(token_decoder).to receive(:decode_token)
          end

          it 'does not set the X-USER-GUID header' do
            _, header, = middleware.call({})
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
              allow(VCAP::CloudController::SecurityContext).to receive_messages(valid_token?: false, missing_token?: false)
            end

            it 'changes the response to 401' do
              status, headers, body = middleware.call(env)
              expect(status).to eq(401)
              expect(headers).to eq({ 'Content-Length' => '189', 'Content-Type' => 'application/json', 'X-RateLimit-Remaining' => '0' })
              json_body = Oj.load(body.first)
              expect(json_body).to include(
                'code' => 1000,
                'description' => 'Invalid Auth Token',
                'error_code' => 'CF-InvalidAuthToken'
              )
            end
          end

          context 'when token is missing' do
            before do
              allow(VCAP::CloudController::SecurityContext).to receive_messages(valid_token?: false, missing_token?: true)
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
            status, = middleware.call(env)
            expect(status).to eq(502)
          end

          it 'sets the Content-Type header' do
            _, headers, = middleware.call(env)
            expect(headers['Content-Type']).to eq('application/json')
          end

          context 'when the path is /v2/*' do
            it 'throws an error' do
              _, _, body = middleware.call(env)
              json_body = Oj.load(body.first)
              expect(json_body).to include(
                'code' => 20_004,
                'description' => 'The UAA service is currently unavailable',
                'error_code' => 'CF-UaaUnavailable'
              )
            end
          end

          context 'when the path is /v3/*' do
            let(:path_info) { '/v3/foo' }

            it 'throws an error' do
              _, _, body = middleware.call(env)
              json_body = Oj.load(body.first)
              expect(json_body['errors'].first).to include(
                'code' => 20_004,
                'detail' => 'The UAA service is currently unavailable',
                'title' => 'CF-UaaUnavailable'
              )
            end
          end
        end

        context 'when an error is raised after calling the next middleware' do
          let(:error) { RuntimeError.new('oops') }

          before do
            allow(app).to receive(:call).and_raise(error)
          end

          it 'unsets the user_guid on the request' do
            expect(::VCAP::Request).to receive(:user_guid=).with('user-id-1')
            expect(::VCAP::Request).to receive(:user_guid=).with(nil)
            expect { middleware.call(env) }.to raise_error(error)
          end
        end

        context 'when the request targets an upload endpoint' do
          let(:path_info) { '/v3/packages/0b6a2f0e-9c5a-4c1d-8e2f-1a2b3c4d5e6f/upload' }
          let(:upload_env) do
            {
              'HTTP_AUTHORIZATION' => 'auth-token',
              'PATH_INFO' => path_info,
              'REQUEST_PATH' => path_info,
              'REQUEST_METHOD' => 'POST',
              'QUERY_STRING' => query_string,
              'CONTENT_TYPE' => content_type,
              'rack.input' => StringIO.new(request_body)
            }
          end
          let(:query_string) { '' }
          let(:content_type) { 'application/x-www-form-urlencoded' }
          let(:request_body) { '' }

          context 'when upload_start_time is absent from the POST body' do
            it 'uses the strict token decoder' do
              expect(VCAP::CloudController::UaaTokenDecoder).not_to receive(:new)

              middleware.call(upload_env)
            end
          end

          context 'when upload_start_time is passed as a query parameter (client-supplied, ignored)' do
            let(:query_string) { 'upload_start_time=123' }

            it 'ignores it and uses the strict token decoder' do
              expect(VCAP::CloudController::UaaTokenDecoder).not_to receive(:new)

              middleware.call(upload_env)
            end
          end

          context 'when upload_start_time is in the POST body (as injected by nginx upload module)' do
            let(:request_body) { 'upload_start_time=123' }

            it 'uses a relaxed token decoder with the given reference time' do
              expect(VCAP::CloudController::UaaTokenDecoder).to receive(:new).
                with(anything, alternate_reference_time: 123).and_return(token_decoder)

              middleware.call(upload_env)
            end
          end

          context 'when upload_start_time in the POST body is in the future' do
            let(:request_body) { 'upload_start_time=9999999999' }

            it 'clamps the reference time to now' do
              Timecop.freeze do
                expect(VCAP::CloudController::UaaTokenDecoder).to receive(:new).
                  with(anything, alternate_reference_time: Time.now.to_i).and_return(token_decoder)
                middleware.call(upload_env)
              end
            end
          end

          context 'when upload_start_time in the POST body is not a positive integer' do
            let(:request_body) { 'upload_start_time=abc' }

            it 'uses the strict token decoder' do
              expect(VCAP::CloudController::UaaTokenDecoder).not_to receive(:new)

              middleware.call(upload_env)
            end
          end

          context 'when upload_start_time in the POST body is empty' do
            let(:request_body) { 'upload_start_time=' }

            it 'uses the strict token decoder' do
              expect(VCAP::CloudController::UaaTokenDecoder).not_to receive(:new)

              middleware.call(upload_env)
            end
          end
        end
      end
    end
  end
end
