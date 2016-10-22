require 'spec_helper'

module CloudFoundry
  module Middleware
    RSpec.describe RateLimiter do
      let(:middleware) { RateLimiter.new(
        app,
        general_limit: general_limit,
        unauthenticated_limit: unauthenticated_limit,
        interval: interval
      )
      }

      let(:app) { double(:app, call: [200, {}, 'a body']) }
      let(:general_limit) { 100 }
      let(:unauthenticated_limit) { 10 }
      let(:interval) { 60 }

      let(:unauthenticated_env) { { some: 'env' } }
      let(:user_1_env) { { 'cf.user_guid' => 'user-id-1' } }
      let(:user_2_env) { { 'cf.user_guid' => 'user-id-2' } }

      describe 'headers' do
        describe 'X-RateLimit-Limit' do
          it 'shows the user the total request limit' do
            _, response_headers, _ = middleware.call(user_1_env)
            expect(response_headers['X-RateLimit-Limit']).to eq('100')

            _, response_headers, _ = middleware.call(user_1_env)
            expect(response_headers['X-RateLimit-Limit']).to eq('100')
          end
        end

        describe 'X-RateLimit-Remaining' do
          it 'shows the user the number of remaining requests' do
            _, response_headers, _ = middleware.call(user_1_env)
            expect(response_headers['X-RateLimit-Remaining']).to eq('99')

            _, response_headers, _ = middleware.call(user_1_env)
            expect(response_headers['X-RateLimit-Remaining']).to eq('98')
          end

          it 'tracks user\'s remaining requests independently' do
            _, response_headers, _ = middleware.call(user_1_env)
            expect(response_headers['X-RateLimit-Remaining']).to eq('99')
            _, response_headers, _ = middleware.call(user_1_env)
            expect(response_headers['X-RateLimit-Remaining']).to eq('98')

            _, response_headers, _ = middleware.call(user_2_env)
            expect(response_headers['X-RateLimit-Remaining']).to eq('99')
          end

          it 'resets remaining requests after the interval is over' do
            Timecop.freeze do
              _, response_headers, _ = middleware.call(user_1_env)
              expect(response_headers['X-RateLimit-Remaining']).to eq('99')

              Timecop.travel(Time.now + 61.minutes)

              _, response_headers, _ = middleware.call(user_1_env)
              expect(response_headers['X-RateLimit-Remaining']).to eq('99')
            end
          end
        end

        describe 'X-RateLimit-Reset' do
          it 'shows the user when the interval will expire' do
            Timecop.freeze do
              valid_until = Time.now + interval.minutes
              _, response_headers, _ = middleware.call(user_1_env)
              expect(response_headers['X-RateLimit-Reset']).to eq(valid_until.utc.to_i.to_s)

              Timecop.travel(Time.now + 30.minutes)

              _, response_headers, _ = middleware.call(user_1_env)
              expect(response_headers['X-RateLimit-Reset']).to eq(valid_until.utc.to_i.to_s)
            end
          end

          it 'tracks users independently' do
            Timecop.freeze do
              valid_until = Time.now + interval.minutes
              _, response_headers, _ = middleware.call(user_1_env)
              expect(response_headers['X-RateLimit-Reset']).to eq(valid_until.utc.to_i.to_s)

              Timecop.travel(Time.now + 1.minutes)
              valid_until_2 = Time.now + interval.minutes

              _, response_headers, _ = middleware.call(user_2_env)
              expect(response_headers['X-RateLimit-Reset']).to eq(valid_until_2.utc.to_i.to_s)
            end
          end

          it 'resets after the interval' do
            Timecop.freeze do
              valid_until = Time.now + interval.minutes
              _, response_headers, _ = middleware.call(user_1_env)
              expect(response_headers['X-RateLimit-Reset']).to eq(valid_until.utc.to_i.to_s)

              Timecop.travel(Time.now + 61.minutes)
              valid_until = Time.now + 60.minutes
              _, response_headers, _ = middleware.call(user_1_env)
              expect(response_headers['X-RateLimit-Reset']).to eq(valid_until.utc.to_i.to_s)
            end
          end
        end
      end

      it 'allows the request to continue' do
        _, _, _ = middleware.call(user_1_env)
        expect(app).to have_received(:call)
      end

      it 'does not drop headers created in next middleware' do
        allow(app).to receive(:call).and_return([200, { 'from' => 'wrapped-app' }, 'a body'])
        _, headers, _ = middleware.call({})
        expect(headers).to match(hash_including('from' => 'wrapped-app'))
      end

      describe 'when the user is not logged in' do
        describe 'when the user has a "HTTP_X_FORWARDED_FOR" header from proxy' do
          let(:headers) { ActionDispatch::Http::Headers.new({ 'HTTP_X_FORWARDED_FOR' => 'forwarded_ip' }) }
          let(:headers_2) { ActionDispatch::Http::Headers.new({ 'HTTP_X_FORWARDED_FOR' => 'forwarded_ip_2' }) }
          let(:fake_request) { instance_double(ActionDispatch::Request, headers: headers, ip: 'proxy-ip') }
          let(:fake_request_2) { instance_double(ActionDispatch::Request, headers: headers_2, ip: 'proxy-ip') }

          it 'uses unauthenticated_limit instead of general_limit' do
            allow(ActionDispatch::Request).to receive(:new).and_return(fake_request)
            _, response_headers, _ = middleware.call(unauthenticated_env)
            expect(response_headers['X-RateLimit-Limit']).to eq('10')
            expect(response_headers['X-RateLimit-Remaining']).to eq('9')
          end

          it 'identifies them by the "HTTP_X_FORWARDED_FOR" header' do
            Timecop.freeze do
              valid_until = Time.now + interval.minutes

              allow(ActionDispatch::Request).to receive(:new).and_return(fake_request)
              _, response_headers, _ = middleware.call(unauthenticated_env)
              expect(response_headers['X-RateLimit-Limit']).to eq('10')
              expect(response_headers['X-RateLimit-Remaining']).to eq('9')
              expect(response_headers['X-RateLimit-Reset']).to eq(valid_until.utc.to_i.to_s)

              _, response_headers, _ = middleware.call(unauthenticated_env)
              expect(response_headers['X-RateLimit-Limit']).to eq('10')
              expect(response_headers['X-RateLimit-Remaining']).to eq('8')
              expect(response_headers['X-RateLimit-Reset']).to eq(valid_until.utc.to_i.to_s)

              allow(ActionDispatch::Request).to receive(:new).and_return(fake_request_2)
              _, response_headers, _ = middleware.call(unauthenticated_env)
              expect(response_headers['X-RateLimit-Limit']).to eq('10')
              expect(response_headers['X-RateLimit-Remaining']).to eq('9')
              expect(response_headers['X-RateLimit-Reset']).to eq(valid_until.utc.to_i.to_s)
            end
          end
        end

        describe 'when the there is no "HTTP_X_FORWARDED_FOR" header' do
          let(:headers) { ActionDispatch::Http::Headers.new({ 'X_HEADER' => 'nope' }) }
          let(:fake_request) { instance_double(ActionDispatch::Request, headers: headers, ip: 'some-ip') }
          let(:fake_request_2) { instance_double(ActionDispatch::Request, headers: headers, ip: 'some-ip-2') }

          it 'uses unauthenticated_limit instead of general_limit' do
            allow(ActionDispatch::Request).to receive(:new).and_return(fake_request)
            _, response_headers, _ = middleware.call(unauthenticated_env)
            expect(response_headers['X-RateLimit-Limit']).to eq('10')
            expect(response_headers['X-RateLimit-Remaining']).to eq('9')
          end

          it 'identifies them by the request ip' do
            Timecop.freeze do
              valid_until = Time.now + interval.minutes

              allow(ActionDispatch::Request).to receive(:new).and_return(fake_request)
              _, response_headers, _ = middleware.call(unauthenticated_env)
              expect(response_headers['X-RateLimit-Limit']).to eq('10')
              expect(response_headers['X-RateLimit-Remaining']).to eq('9')
              expect(response_headers['X-RateLimit-Reset']).to eq(valid_until.utc.to_i.to_s)

              _, response_headers, _ = middleware.call(unauthenticated_env)
              expect(response_headers['X-RateLimit-Limit']).to eq('10')
              expect(response_headers['X-RateLimit-Remaining']).to eq('8')
              expect(response_headers['X-RateLimit-Reset']).to eq(valid_until.utc.to_i.to_s)

              allow(ActionDispatch::Request).to receive(:new).and_return(fake_request_2)
              _, response_headers, _ = middleware.call(unauthenticated_env)
              expect(response_headers['X-RateLimit-Limit']).to eq('10')
              expect(response_headers['X-RateLimit-Remaining']).to eq('9')
              expect(response_headers['X-RateLimit-Reset']).to eq(valid_until.utc.to_i.to_s)
            end
          end
        end
      end

      context 'when user has admin or admin_read_only scopes' do
        let(:general_limit) { 1 }

        before do
          allow(VCAP::CloudController::SecurityContext).to receive(:admin_read_only?).and_return(true)
        end
        it 'does not rate limit' do
          _, _, _ = middleware.call(user_1_env)
          _, _, _ = middleware.call(user_1_env)
          status, response_headers, _ = middleware.call(user_1_env)
          expect(response_headers['X-RateLimit-Remaining']).to eq('0')
          expect(status).to eq(200)
          expect(app).to have_received(:call).at_least(:once)
        end
      end

      context 'when limit exceeded' do
        let(:general_limit) { 0 }
        let(:path_info) { '/v2/foo' }
        let(:middleware_env) do
          { 'cf.user_guid' => 'user-id-1', 'PATH_INFO' => path_info }
        end

        it 'returns 429 response' do
          status, _, _ = middleware.call(middleware_env)
          expect(status).to eq(429)
        end

        it 'prevents "X-RateLimit-Remaining" from going lower than zero' do
          _, response_headers, _ = middleware.call(middleware_env)
          expect(response_headers['X-RateLimit-Remaining']).to eq('0')
          _, response_headers, _ = middleware.call(middleware_env)
          expect(response_headers['X-RateLimit-Remaining']).to eq('0')
        end

        it 'contains the correct headers' do
          Timecop.freeze do
            error_presenter = instance_double(ErrorPresenter, to_hash: { foo: 'bar' })
            allow(ErrorPresenter).to receive(:new).and_return(error_presenter)

            valid_until = Time.now + interval.minutes
            _, response_headers, _ = middleware.call(middleware_env)
            expect(response_headers['Retry-After']).to eq(valid_until.utc.to_i.to_s)
            expect(response_headers['Content-Type']).to eq('text/plain; charset=utf-8')
            expect(response_headers['Content-Length']).to eq({ foo: 'bar' }.to_json.length.to_s)
          end
        end

        it 'ends the request' do
          _, _, _ = middleware.call(middleware_env)
          expect(app).not_to have_received(:call)
        end

        context 'when the path is /v2/*' do
          it 'formats the response error in v2 format' do
            _, _, body = middleware.call(middleware_env)
            json_body = JSON.parse(body.first)
            expect(json_body).to include(
              'code' => 10013,
              'description' => 'Rate Limit Exceeded',
              'error_code' => 'CF-RateLimitExceeded',
            )
          end
        end

        context 'when the path is /v3/*' do
          let(:path_info) { '/v3/foo' }

          it 'formats the response error in v3 format' do
            _, _, body = middleware.call(middleware_env)
            json_body = JSON.parse(body.first)
            expect(json_body['errors'].first).to include(
              'code' => 10013,
              'detail' => 'Rate Limit Exceeded',
              'title' => 'CF-RateLimitExceeded',
            )
          end
        end
      end

      context 'with multiple servers' do
        let(:other_middleware) { RateLimiter.new(
          app,
          general_limit: general_limit,
          unauthenticated_limit: unauthenticated_limit,
          interval: interval
        )
        }

        it 'shares request count between servers' do
          _, response_headers, _ = middleware.call(user_1_env)
          expect(response_headers['X-RateLimit-Remaining']).to eq('99')
          _, response_headers, _ = other_middleware.call(user_1_env)
          expect(response_headers['X-RateLimit-Remaining']).to eq('98')
        end
      end
    end
  end
end
