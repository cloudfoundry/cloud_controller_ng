require 'spec_helper'

module CloudFoundry
  module Middleware
    RSpec.describe ConcurrencyRateLimiter do
      let(:app) { double(:app, call: [200, {}, 'a body']) }
      let(:logger) { double('logger', info: nil, error: nil) }
      let(:user_guid) { 'user-id-1' }
      let(:user_env) { { 'cf.user_guid' => user_guid, 'PATH_INFO' => '/v3/apps' } }
      let(:blocking_limit) { 2 }
      let(:logging_limit) { nil }
      let(:counter) do
        instance_double(ConcurrentRequestCounter, try_increment?: true, decrement: nil)
      end

      let(:middleware) do
        ConcurrencyRateLimiter.new(app, logger: logger, blocking_limit: blocking_limit, logging_limit: logging_limit)
      end

      before do
        allow(ConcurrentRequestCounter).to receive(:instance).and_return(counter)
      end

      describe '#call' do
        context 'when under the limit' do
          it 'passes the request through' do
            status, = middleware.call(user_env)
            expect(status).to eq(200)
          end

          it 'decrements after the request completes' do
            middleware.call(user_env)
            expect(counter).to have_received(:decrement).with(user_guid, logger)
          end
        end

        context 'when over the limit' do
          before do
            allow(counter).to receive(:try_increment?).and_return(false)
          end

          it 'returns 429' do
            status, = middleware.call(user_env)
            expect(status).to eq(429)
          end

          it 'does not call the app' do
            middleware.call(user_env)
            expect(app).not_to have_received(:call)
          end

          it 'does not decrement after the blocked request' do
            middleware.call(user_env)
            expect(counter).not_to have_received(:decrement)
          end

          it 'includes Retry-After header as seconds' do
            _, response_headers, = middleware.call(user_env)
            expect(response_headers['Retry-After'].to_i).to be > 0
          end

          context 'when the path is /v3' do
            it 'formats the error in v3 format' do
              _, _, body = middleware.call(user_env)
              json_body = Oj.load(body.first)
              expect(json_body['errors'].first).to include(
                'title' => 'CF-ConcurrentRequestLimitExceeded',
                'code' => 10_021
              )
            end
          end

          context 'when the path is /v2' do
            let(:user_env) { { 'cf.user_guid' => user_guid, 'PATH_INFO' => '/v2/apps' } }

            it 'formats the error in v2 format' do
              _, _, body = middleware.call(user_env)
              json_body = Oj.load(body.first)
              expect(json_body).to include(
                'error_code' => 'CF-ConcurrentRequestLimitExceeded',
                'code' => 10_021
              )
            end
          end
        end

        context 'when an error is raised in the app' do
          before do
            allow(app).to receive(:call).and_raise('an error')
          end

          it 'still decrements' do
            expect { middleware.call(user_env) }.to raise_error('an error')
            expect(counter).to have_received(:decrement).with(user_guid, logger)
          end
        end

        context 'when using an unauthenticated request (IP-based)' do
          let(:ip_env) { { 'PATH_INFO' => '/v3/apps' } }
          let(:fake_request) do
            headers = ActionDispatch::Http::Headers.from_hash({ 'HTTP_X_FORWARDED_FOR' => '1.2.3.4' })
            instance_double(ActionDispatch::Request, fullpath: '/v3/apps', ip: '10.0.0.1', headers: headers)
          end

          before do
            allow(ActionDispatch::Request).to receive(:new).and_return(fake_request)
          end

          it 'uses the X-Forwarded-For IP as the user identifier' do
            middleware.call(ip_env)
            expect(counter).to have_received(:try_increment?).with('1.2.3.4', anything)
          end

          context 'when over the limit' do
            before do
              allow(counter).to receive(:try_increment?).and_return(false)
            end

            it 'uses the IP-based error name' do
              _, _, body = middleware.call(ip_env)
              json_body = Oj.load(body.first)
              expect(json_body['errors'].first['title']).to eq('CF-IPBasedConcurrentRequestLimitExceeded')
            end
          end
        end

        describe 'bypassed requests' do
          context 'internal API' do
            let(:internal_env) { { 'cf.user_guid' => user_guid, 'PATH_INFO' => '/internal/v4/asg_latest_update' } }
            let(:request_double) { instance_double(ActionDispatch::Request, fullpath: '/internal/v4/asg_latest_update') }

            before { allow(ActionDispatch::Request).to receive(:new).and_return(request_double) }

            it 'does not rate limit' do
              middleware.call(internal_env)
              expect(counter).not_to have_received(:try_increment?)
            end
          end

          context 'root API paths' do
            %w[/v2/info /v3 / /healthz].each do |path|
              context path do
                let(:root_env) { { 'cf.user_guid' => user_guid, 'PATH_INFO' => path } }
                let(:request_double) { instance_double(ActionDispatch::Request, fullpath: path) }

                before { allow(ActionDispatch::Request).to receive(:new).and_return(request_double) }

                it 'does not rate limit' do
                  middleware.call(root_env)
                  expect(counter).not_to have_received(:try_increment?)
                end
              end
            end
          end

          context 'basic auth request' do
            let(:basic_auth_env) do
              user_env.merge('HTTP_AUTHORIZATION' => 'Basic ' + Base64.encode64('user:pass').strip)
            end

            it 'does not rate limit' do
              middleware.call(basic_auth_env)
              expect(counter).not_to have_received(:try_increment?)
            end
          end
        end
      end
    end
  end
end
