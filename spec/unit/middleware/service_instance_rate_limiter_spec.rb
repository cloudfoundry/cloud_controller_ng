require 'spec_helper'

module CloudFoundry
  module Middleware
    RSpec.describe RateLimiter do
      let(:middleware) do
        RateLimiter.new(
          app,
          logger:                logger,
          general_limit_enabled: general_limit_enabled,
          general_limit:         general_limit,
          unauthenticated_limit: unauthenticated_limit,
          interval:              interval,
          service_rate_limit_enabled: service_rate_limit_enabled,
          service_limit:         service_limit,
          service_interval:      service_interval
        )
      end

      let(:app) { double(:app, call: [200, {}, 'a body']) }
      let(:general_limit_enabled) { true }
      let(:general_limit) { 100 }
      let(:unauthenticated_limit) { 10 }
      let(:interval) { 60 }
      let(:service_rate_limit_enabled) { true }
      let(:service_limit) { 5 }
      let(:service_interval) { 6 }
      let(:logger) { double('logger', info: nil) }

      let(:path_info) { '/v2/service_instances' }
      let(:v2_path_info) { '/v2/service_instances' }
      let(:v3_path_info) { '/v3/service_instances' }

      let(:unauthenticated_env) { { some: 'env', 'PATH_INFO' => v2_path_info, 'REQUEST_METHOD' => 'POST' } }
      let(:basic_auth_env) { { 'HTTP_AUTHORIZATION' => ActionController::HttpAuthentication::Basic.encode_credentials('user', 'pass'),
                               'PATH_INFO' => v2_path_info,
                               'REQUEST_METHOD' => 'POST'
                            }
      }
      let(:user_1_env) { { 'cf.user_guid' => 'user-id-1', 'PATH_INFO' => v2_path_info, 'REQUEST_METHOD' => 'POST' } }
      let(:user_1_v3_env) { { 'cf.user_guid' => 'user-id-1', 'PATH_INFO' => v3_path_info, 'REQUEST_METHOD' => 'POST' } }
      let(:user_2_env) { { 'cf.user_guid' => 'user-id-2', 'PATH_INFO' => v2_path_info, 'REQUEST_METHOD' => 'POST' } }
      let(:post_env) { { 'cf.user_guid' => 'post-user', 'PATH_INFO' => v2_path_info, 'REQUEST_METHOD' => 'POST' } }
      let(:patch_env) { { 'cf.user_guid' => 'patch-user', 'PATH_INFO' => v3_path_info, 'REQUEST_METHOD' => 'PATCH' } }
      let(:put_env) { { 'cf.user_guid' => 'put-user', 'PATH_INFO' => v2_path_info, 'REQUEST_METHOD' => 'PUT' } }
      let(:get_env) { { 'cf.user_guid' => 'get-user', 'PATH_INFO' => v2_path_info, 'REQUEST_METHOD' => 'GET' } }

      describe 'servce_instance headers' do
        describe 'X-RateLimit-Limit' do
          it 'shows the user the total request limit' do
            _, response_headers, _ = middleware.call(user_1_env)
            expect(response_headers['X-RateLimit-Limit']).to eq('5')

            _, response_headers, _ = middleware.call(user_1_env)
            expect(response_headers['X-RateLimit-Limit']).to eq('5')
          end
        end

        describe 'X-RateLimit-Remaining' do
          it 'shows the user the number of remaining requests' do
            _, response_headers, _ = middleware.call(user_1_env)
            expect(response_headers['X-RateLimit-Remaining']).to eq('4')

            _, response_headers, _ = middleware.call(user_1_env)
            expect(response_headers['X-RateLimit-Remaining']).to eq('3')
          end

          describe 'rate limits only specific methods' do
            it 'rate limits POST methods' do
              status, response_headers, _ = middleware.call(post_env)
              expect(response_headers['X-RateLimit-Remaining']).to eq('4')
              expect(status).to eq(200)
              expect(app).to have_received(:call).at_least(:once)
            end

            it 'rate limits PATCH methods' do
              status, response_headers, _ = middleware.call(patch_env)
              expect(response_headers['X-RateLimit-Remaining']).to eq('4')
              expect(status).to eq(200)
              expect(app).to have_received(:call).at_least(:once)
            end

            it 'rate limits PUT methods' do
              status, response_headers, _ = middleware.call(patch_env)
              expect(response_headers['X-RateLimit-Remaining']).to eq('4')
              expect(status).to eq(200)
              expect(app).to have_received(:call).at_least(:once)
            end

            it 'does not rate limit GET or other methods' do
              status, response_headers, _ = middleware.call(get_env)
              expect(response_headers['X-RateLimit-Remaining']).to eq('99') # runs into the general limit
              expect(status).to eq(200)
              expect(app).to have_received(:call).at_least(:once)
            end
          end
          it 'tracks user\'s remaining requests independently' do
            _, response_headers, _ = middleware.call(user_1_env)
            expect(response_headers['X-RateLimit-Remaining']).to eq('4')
            _, response_headers, _ = middleware.call(user_1_env)
            expect(response_headers['X-RateLimit-Remaining']).to eq('3')

            _, response_headers, _ = middleware.call(user_2_env)
            expect(response_headers['X-RateLimit-Remaining']).to eq('4')
          end

          it 'tracks requests across different API versions' do
            _, response_headers, _ = middleware.call(user_1_env)
            expect(response_headers['X-RateLimit-Remaining']).to eq('4')
            _, response_headers, _ = middleware.call(user_1_env)
            expect(response_headers['X-RateLimit-Remaining']).to eq('3')

            _, response_headers, _ = middleware.call(user_1_v3_env)
            expect(response_headers['X-RateLimit-Remaining']).to eq('2')
          end

          it 'resets remaining requests after the interval is over' do
            Timecop.freeze do
              _, response_headers, _ = middleware.call(user_1_env)
              expect(response_headers['X-RateLimit-Remaining']).to eq('4')

              Timecop.travel(Time.now + 6.minutes)

              _, response_headers, _ = middleware.call(user_1_env)
              expect(response_headers['X-RateLimit-Remaining']).to eq('4')
            end
          end
        end

        describe 'X-RateLimit-Reset' do
          it 'shows the user when the interval will expire' do
            Timecop.freeze do
              valid_until = Time.now + service_interval.minutes
              _, response_headers, _ = middleware.call(user_1_env)
              expect(response_headers['X-RateLimit-Reset'].to_i).to be_within(1).of(valid_until.utc.to_i)

              Timecop.travel(Time.now + 3.minutes)

              _, response_headers, _ = middleware.call(user_1_env)
              expect(response_headers['X-RateLimit-Reset'].to_i).to be_within(1).of(valid_until.utc.to_i)
            end
          end

          it 'tracks users independently' do
            Timecop.freeze do
              valid_until = Time.now + service_interval.minutes
              _, response_headers, _ = middleware.call(user_1_env)
              expect(response_headers['X-RateLimit-Reset'].to_i).to be_within(1).of(valid_until.utc.to_i)

              Timecop.travel(Time.now + 1.minutes)
              valid_until_2 = Time.now + service_interval.minutes

              _, response_headers, _ = middleware.call(user_2_env)
              expect(response_headers['X-RateLimit-Reset'].to_i).to be_within(1).of(valid_until_2.utc.to_i)
            end
          end

          it 'resets after the interval' do
            Timecop.freeze do
              valid_until = Time.now + service_interval.minutes
              _, response_headers, _ = middleware.call(user_1_env)
              expect(response_headers['X-RateLimit-Reset'].to_i).to be_within(1).of(valid_until.utc.to_i)

              Timecop.travel(Time.now + 91.minutes)
              valid_until = Time.now + service_interval.minutes
              _, response_headers, _ = middleware.call(user_1_env)
              expect(response_headers['X-RateLimit-Reset'].to_i).to be_within(1).of(valid_until.utc.to_i)
            end
          end
        end
      end

      it 'allows the service_instance request to continue' do
        middleware.call(user_1_env)
        expect(app).to have_received(:call)
      end

      it 'does not drop headers created in next middleware to service_instances requests' do
        allow(app).to receive(:call).and_return([200, { 'from' => 'wrapped-app' }, 'a body'])
        _, headers, _ = middleware.call({ 'PATH_INFO' => path_info, 'REQUEST_METHOD' => 'POST' })
        expect(headers).to match(hash_including('from' => 'wrapped-app'))
      end

      it 'logs the service instance request count when the interval expires' do
        Timecop.freeze do
          middleware.call(user_1_env)

          Timecop.travel(Time.now + interval.minutes + 1.minute)
          middleware.call(user_1_env)
          expect(logger).to have_received(:info).with "Resetting service instance request count of 1 for user 'user-id-1'"
        end
      end

      describe 'when the user is not logged in and accesses services_instances' do
        describe 'when the user has basic auth credentials' do
          it 'exempts them from rate limiting' do
            _, response_headers, _ = middleware.call(basic_auth_env)
            expect(response_headers['X-RateLimit-Limit']).to be_nil
            expect(response_headers['X-RateLimit-Remaining']).to be_nil
            expect(response_headers['X-RateLimit-Reset']).to be_nil
          end
        end

        describe 'when the user has a "HTTP_X_FORWARDED_FOR" header from proxy' do
          let(:headers) { ActionDispatch::Http::Headers.from_hash({ 'HTTP_X_FORWARDED_FOR' => 'forwarded_ip' }) }
          let(:headers_2) { ActionDispatch::Http::Headers.from_hash({ 'HTTP_X_FORWARDED_FOR' => 'forwarded_ip_2' }) }
          let(:fake_request) { instance_double(ActionDispatch::Request, headers: headers, ip: 'proxy-ip', fullpath: '/v2/service_instances/') }
          let(:fake_request_2) { instance_double(ActionDispatch::Request, headers: headers_2, ip: 'proxy-ip', fullpath: '/v2/service_instances/coolstuff') }

          before do
            allow(fake_request).to receive(:fetch_header).with('HTTP_X_FORWARDED_FOR').and_return('forwarded_ip')
            allow(fake_request_2).to receive(:fetch_header).with('HTTP_X_FORWARDED_FOR').and_return('forwarded_ip_2')
          end

          it 'uses unauthenticated_limit instead of service_instance limit' do
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
          let(:headers) { ActionDispatch::Http::Headers.from_hash({ 'X_HEADER' => 'nope' }) }
          let(:fake_request) { instance_double(ActionDispatch::Request, headers: headers, ip: 'some-ip', fullpath: '/v2/service_instances/notcoolstuff') }
          let(:fake_request_2) { instance_double(ActionDispatch::Request, headers: headers, ip: 'some-ip-2', fullpath: '/v2/service_instances/') }

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
        let(:service_limit) { 1 }

        before do
          allow(VCAP::CloudController::SecurityContext).to receive(:admin_read_only?).and_return(true)
        end
        it 'does not rate limit' do
          middleware.call(user_1_env)
          middleware.call(user_1_env)
          status, response_headers, _ = middleware.call(user_1_env)
          expect(response_headers).not_to include('X-RateLimit-Remaining')
          expect(status).to eq(200)
          expect(app).to have_received(:call).at_least(:once)
        end
      end

      context 'when limit has exceeded' do
        let(:general_limit) { 0 }
        let(:service_limit) { 0 }
        let(:middleware_env) do
          { 'cf.user_guid' => 'user-id-1', 'PATH_INFO' => path_info, 'REQUEST_METHOD' => 'POST' }
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

            valid_until = Time.now + service_interval.minutes
            _, response_headers, _ = middleware.call(middleware_env)
            expect(response_headers['Retry-After']).to eq(valid_until.utc.to_i.to_s)
            expect(response_headers['Content-Type']).to eq('text/plain; charset=utf-8')
            expect(response_headers['Content-Length']).to eq({ foo: 'bar' }.to_json.length.to_s)
          end
        end

        it 'ends the request' do
          middleware.call(middleware_env)
          expect(app).not_to have_received(:call)
        end

        context 'when the path is /v2/service_instances' do
          it 'formats the response error in v2 format' do
            _, _, body = middleware.call(middleware_env)
            json_body = JSON.parse(body.first)
            expect(json_body).to include(
              'code' => 10016,
              'description' => 'Service Instance Rate Limit Exceeded',
              'error_code' => 'CF-ServiceInstanceRateLimitExceeded',
            )
          end
        end

        context 'when the path is /v3/*' do
          let(:path_info) { '/v3/service_instances' }

          it 'formats the response error in v3 format' do
            _, _, body = middleware.call(middleware_env)
            json_body = JSON.parse(body.first)
            expect(json_body['errors'].first).to include(
              'code' => 10016,
              'detail' => 'Service Instance Rate Limit Exceeded',
              'title' => 'CF-ServiceInstanceRateLimitExceeded',
            )
          end
        end

        context 'when the user is unauthenticated' do
          let(:path_info) { '/v3/service_instances' }
          let(:unauthenticated_env) { { 'some' => 'env', 'PATH_INFO' => path_info } }

          it 'suggests they log in' do
            10.times do
              middleware.call(unauthenticated_env)
            end
            _, response_headers, body = middleware.call(unauthenticated_env)
            expect(response_headers['X-RateLimit-Remaining']).to eq('0')
            json_body = JSON.parse(body.first)
            expect(json_body['errors'].first).to include(
              'code' => 10014,
              'detail' => 'Rate Limit Exceeded: Unauthenticated requests from this IP address have exceeded the limit. Please log in.',
              'title' => 'CF-IPBasedRateLimitExceeded',
            )
          end
        end
      end

      context 'with multiple servers' do
        let(:other_middleware) do
          RateLimiter.new(
            app,
            logger:                logger,
            general_limit_enabled: general_limit_enabled,
            general_limit:         general_limit,
            unauthenticated_limit: unauthenticated_limit,
            interval:              interval,
            service_rate_limit_enabled: service_rate_limit_enabled,
            service_limit:         service_limit,
            service_interval:      service_interval
          )
        end

        it 'shares request count between servers' do
          _, response_headers, _ = middleware.call(user_1_env)
          expect(response_headers['X-RateLimit-Remaining']).to eq('4')
          _, response_headers, _ = other_middleware.call(user_1_env)

          expect(response_headers['X-RateLimit-Remaining']).to eq('3')
        end
      end

      context 'with different rate limters enabled' do
        context 'with rate limits general off, service_instance on' do
          let(:middleware_general_on_services_off) do
            RateLimiter.new(
              app,
              logger:                logger,
              general_limit_enabled: general_limit_enabled,
              general_limit:         general_limit,
              unauthenticated_limit: unauthenticated_limit,
              interval:              interval,
              service_rate_limit_enabled: service_rate_limit_enabled,
              service_limit:         service_limit,
              service_interval:      service_interval
            )
          end
          let(:app) { double(:app, call: [200, {}, 'a body']) }
          let(:general_limit_enabled) { false }
          let(:service_rate_limit_enabled) { true }
          let(:path_info) { '/v2/service_instances' }
          let(:service_instance_env) { { 'cf.user_guid' => 'user-id-1', 'PATH_INFO' => path_info, 'REQUEST_METHOD' => 'POST' } }
          let(:general_env) { { 'cf.user_guid' => 'user-id-1' } }

          it 'rate limits generally and not the service_instances' do
            _, response_headers, _ = middleware_general_on_services_off.call(service_instance_env)
            expect(response_headers['X-RateLimit-Remaining']).to eq('4')

            _, response_headers, _ = middleware_general_on_services_off.call(service_instance_env)
            expect(response_headers['X-RateLimit-Remaining']).to eq('3')

            status, response_headers, _ = middleware_general_on_services_off.call(general_env)
            expect(response_headers['X-RateLimit-Remaining']).to be_nil
            expect(status).to eq(200)

            _, response_headers, _ = middleware_general_on_services_off.call(service_instance_env)
            expect(response_headers['X-RateLimit-Remaining']).to eq('2')
          end
        end
      end
    end
  end
end
