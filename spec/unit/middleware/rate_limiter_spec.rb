require 'spec_helper'

module CloudFoundry
  module Middleware
    RSpec.describe RateLimiter do
      let(:middleware) do
        RateLimiter.new(
          app,
          logger:                      logger,
          general_limit:               general_limit,
          total_general_limit:         total_general_limit,
          unauthenticated_limit:       unauthenticated_limit,
          total_unauthenticated_limit: total_unauthenticated_limit,
          interval:                    interval,
        )
      end
      let(:request_counter) { double }
      before(:each) {
        middleware.instance_variable_set('@request_counter', request_counter)
        allow(request_counter).to receive(:get).and_return([0, Time.now.utc])
        allow(request_counter).to receive(:increment)
      }

      let(:app) { double(:app, call: [200, {}, 'a body']) }
      let(:general_limit) { 100 }
      let(:total_general_limit) { 1000 }
      let(:unauthenticated_limit) { 10 }
      let(:total_unauthenticated_limit) { 100 }
      let(:interval) { 60 }
      let(:logger) { double('logger', info: nil) }

      let(:unauthenticated_env) { { some: 'env' } }
      let(:basic_auth_env) { { 'HTTP_AUTHORIZATION' => ActionController::HttpAuthentication::Basic.encode_credentials('user', 'pass') } }
      let(:user_1_guid) { 'user-id-1' }
      let(:user_2_guid) { 'user-id-2' }
      let(:user_1_env) { { 'cf.user_guid' => user_1_guid } }
      let(:user_2_env) { { 'cf.user_guid' => user_2_guid } }

      describe 'headers' do
        describe 'X-RateLimit-Limit' do
          it 'shows the user the total request limit' do
            _, response_headers, _ = middleware.call(user_1_env)
            expect(response_headers['X-RateLimit-Limit']).to eq(total_general_limit.to_s)

            _, response_headers, _ = middleware.call(user_1_env)
            expect(response_headers['X-RateLimit-Limit']).to eq(total_general_limit.to_s)
          end
        end

        describe 'X-RateLimit-Remaining' do
          it 'shows the user the number of remaining requests rounded down to nearest 10%' do
            allow(request_counter).to receive(:get).and_return([0, Time.now.utc])
            _, response_headers, _ = middleware.call(user_1_env)
            expect(response_headers['X-RateLimit-Remaining']).to eq('900')

            allow(request_counter).to receive(:get).and_return([10, Time.now.utc])
            _, response_headers, _ = middleware.call(user_1_env)
            expect(response_headers['X-RateLimit-Remaining']).to eq('800')
          end

          it 'tracks user\'s remaining requests independently' do
            expect(request_counter).to receive(:get).with(user_1_guid, interval, logger).and_return([0, Time.now.utc])
            expect(request_counter).to receive(:get).with(user_2_guid, interval, logger).and_return([10, Time.now.utc])

            _, response_headers, _ = middleware.call(user_1_env)
            expect(response_headers['X-RateLimit-Remaining']).to eq('900')

            _, response_headers, _ = middleware.call(user_2_env)
            expect(response_headers['X-RateLimit-Remaining']).to eq('800')
          end
        end

        describe 'X-RateLimit-Reset' do
          it 'shows the user when the interval will expire' do
            valid_until = Time.now.utc.beginning_of_hour + interval.minutes
            allow(request_counter).to receive(:get).and_return([0, valid_until])
            _, response_headers, _ = middleware.call(user_1_env)
            expect(response_headers['X-RateLimit-Reset'].to_i).to eq(valid_until.utc.to_i)
          end
        end
      end

      it 'increments the counter and allows the request to continue' do
        _, _, _ = middleware.call(user_1_env)
        expect(request_counter).to have_received(:increment).with(user_1_guid)
        expect(app).to have_received(:call)
      end

      it 'does not drop headers created in next middleware' do
        allow(app).to receive(:call).and_return([200, { 'from' => 'wrapped-app' }, 'a body'])
        _, headers, _ = middleware.call({})
        expect(headers).to match(hash_including('from' => 'wrapped-app'))
      end

      describe 'when the user is not logged in' do
        describe 'when the user has basic auth credentials' do
          it 'exempts them from rate limiting' do
            _, response_headers, _ = middleware.call(basic_auth_env)
            expect(request_counter).not_to have_received(:get)
            expect(request_counter).not_to have_received(:increment)
            expect(response_headers['X-RateLimit-Limit']).to be_nil
            expect(response_headers['X-RateLimit-Remaining']).to be_nil
            expect(response_headers['X-RateLimit-Reset']).to be_nil
          end
        end

        describe 'exempting internal endpoints' do
          context 'when the user is hitting a path starting with "/internal"' do
            let(:fake_request) { instance_double(ActionDispatch::Request, fullpath: '/internal/pants/1234') }

            it 'exempts them from rate limiting' do
              allow(ActionDispatch::Request).to receive(:new).and_return(fake_request)
              _, response_headers, _ = middleware.call(unauthenticated_env)
              expect(request_counter).not_to have_received(:get)
              expect(request_counter).not_to have_received(:increment)
              expect(response_headers['X-RateLimit-Limit']).to be_nil
              expect(response_headers['X-RateLimit-Remaining']).to be_nil
              expect(response_headers['X-RateLimit-Reset']).to be_nil
            end
          end

          context 'when the user is hitting containing, but NOT starting with "/internal"' do
            let(:headers) { ActionDispatch::Http::Headers.from_hash({ 'HTTP_X_FORWARDED_FOR' => 'forwarded_ip' }) }
            let(:fake_request) { instance_double(ActionDispatch::Request, fullpath: '/pants/internal/1234', headers: headers) }

            it 'rate limits them' do
              allow(ActionDispatch::Request).to receive(:new).and_return(fake_request)
              expect(request_counter).to receive(:get).with('forwarded_ip', interval, logger).and_return([0, Time.now.utc])
              expect(request_counter).to receive(:increment).with('forwarded_ip')
              _, response_headers, _ = middleware.call(unauthenticated_env)
              expect(response_headers['X-RateLimit-Limit']).to_not be_nil
              expect(response_headers['X-RateLimit-Remaining']).to_not be_nil
              expect(response_headers['X-RateLimit-Reset']).to_not be_nil
            end
          end
        end

        describe 'exempting root endpoints' do
          context 'when the user is hitting a root path /' do
            let(:fake_request) { instance_double(ActionDispatch::Request, fullpath: '/') }

            it 'exempts them from rate limiting' do
              allow(ActionDispatch::Request).to receive(:new).and_return(fake_request)
              _, response_headers, _ = middleware.call(unauthenticated_env)
              expect(request_counter).not_to have_received(:get)
              expect(request_counter).not_to have_received(:increment)
              expect(response_headers['X-RateLimit-Limit']).to be_nil
              expect(response_headers['X-RateLimit-Remaining']).to be_nil
              expect(response_headers['X-RateLimit-Reset']).to be_nil
            end
          end

          context 'when the user is hitting a root path /v2/info' do
            let(:fake_request) { instance_double(ActionDispatch::Request, fullpath: '/v2/info') }

            it 'exempts them from rate limiting' do
              allow(ActionDispatch::Request).to receive(:new).and_return(fake_request)
              _, response_headers, _ = middleware.call(unauthenticated_env)
              expect(request_counter).not_to have_received(:get)
              expect(request_counter).not_to have_received(:increment)
              expect(response_headers['X-RateLimit-Limit']).to be_nil
              expect(response_headers['X-RateLimit-Remaining']).to be_nil
              expect(response_headers['X-RateLimit-Reset']).to be_nil
            end
          end

          context 'when the user is hitting a root path /v3' do
            let(:fake_request) { instance_double(ActionDispatch::Request, fullpath: '/v3') }

            it 'exempts them from rate limiting' do
              allow(ActionDispatch::Request).to receive(:new).and_return(fake_request)
              _, response_headers, _ = middleware.call(unauthenticated_env)
              expect(request_counter).not_to have_received(:get)
              expect(request_counter).not_to have_received(:increment)
              expect(response_headers['X-RateLimit-Limit']).to be_nil
              expect(response_headers['X-RateLimit-Remaining']).to be_nil
              expect(response_headers['X-RateLimit-Reset']).to be_nil
            end
          end

          context 'when the user is hitting a root path /healthz' do
            let(:fake_request) { instance_double(ActionDispatch::Request, fullpath: '/healthz') }

            it 'exempts them from rate limiting' do
              allow(ActionDispatch::Request).to receive(:new).and_return(fake_request)
              _, response_headers, _ = middleware.call(unauthenticated_env)
              expect(request_counter).not_to have_received(:get)
              expect(request_counter).not_to have_received(:increment)
              expect(response_headers['X-RateLimit-Limit']).to be_nil
              expect(response_headers['X-RateLimit-Remaining']).to be_nil
              expect(response_headers['X-RateLimit-Reset']).to be_nil
            end
          end
        end

        describe 'when the user has a "HTTP_X_FORWARDED_FOR" header from proxy' do
          let(:forwarded_ip) { 'forwarded_ip' }
          let(:forwarded_ip_2) { 'forwarded_ip_2' }
          let(:headers) { ActionDispatch::Http::Headers.from_hash({ 'HTTP_X_FORWARDED_FOR' => forwarded_ip }) }
          let(:headers_2) { ActionDispatch::Http::Headers.from_hash({ 'HTTP_X_FORWARDED_FOR' => forwarded_ip_2 }) }
          let(:fake_request) { instance_double(ActionDispatch::Request, headers: headers, ip: 'proxy-ip', fullpath: '/some/path') }
          let(:fake_request_2) { instance_double(ActionDispatch::Request, headers: headers_2, ip: 'proxy-ip', fullpath: '/some/path') }

          before do
            allow(fake_request).to receive(:fetch_header).with('HTTP_X_FORWARDED_FOR').and_return(forwarded_ip)
            allow(fake_request_2).to receive(:fetch_header).with('HTTP_X_FORWARDED_FOR').and_return(forwarded_ip_2)
          end

          it 'uses unauthenticated_limit instead of general_limit' do
            allow(ActionDispatch::Request).to receive(:new).and_return(fake_request)
            _, response_headers, _ = middleware.call(unauthenticated_env)
            expect(response_headers['X-RateLimit-Limit']).to eq(total_unauthenticated_limit.to_s)
          end

          it 'identifies them by the "HTTP_X_FORWARDED_FOR" header' do
            valid_until = Time.now.utc
            valid_until_2 = Time.now.utc

            allow(ActionDispatch::Request).to receive(:new).and_return(fake_request)
            expect(request_counter).to receive(:get).with(forwarded_ip, interval, logger).and_return([0, valid_until])
            expect(request_counter).to receive(:increment).with(forwarded_ip)
            _, response_headers, _ = middleware.call(unauthenticated_env)
            expect(response_headers['X-RateLimit-Remaining']).to eq('90')
            expect(response_headers['X-RateLimit-Reset']).to eq(valid_until.to_i.to_s)

            allow(ActionDispatch::Request).to receive(:new).and_return(fake_request_2)
            expect(request_counter).to receive(:get).with(forwarded_ip_2, interval, logger).and_return([2, valid_until_2])
            expect(request_counter).to receive(:increment).with(forwarded_ip_2)
            _, response_headers, _ = middleware.call(unauthenticated_env)
            expect(response_headers['X-RateLimit-Remaining']).to eq('70')
            expect(response_headers['X-RateLimit-Reset']).to eq(valid_until_2.to_i.to_s)
          end
        end

        describe 'when the there is no "HTTP_X_FORWARDED_FOR" header' do
          let(:headers) { ActionDispatch::Http::Headers.from_hash({ 'X_HEADER' => 'nope' }) }
          let(:ip) { 'some-ip' }
          let(:ip_2) { 'some-ip-2' }
          let(:fake_request) { instance_double(ActionDispatch::Request, headers: headers, ip: ip, fullpath: '/some/path') }
          let(:fake_request_2) { instance_double(ActionDispatch::Request, headers: headers, ip: ip_2, fullpath: '/some/path') }

          it 'uses unauthenticated_limit instead of general_limit' do
            allow(ActionDispatch::Request).to receive(:new).and_return(fake_request)
            _, response_headers, _ = middleware.call(unauthenticated_env)
            expect(response_headers['X-RateLimit-Limit']).to eq(total_unauthenticated_limit.to_s)
          end

          it 'identifies them by the request ip' do
            valid_until = Time.now.utc.beginning_of_hour
            valid_until_2 = Time.now.utc.beginning_of_hour + 5.minutes
            allow(request_counter).to receive(:get).with(ip, interval, logger).and_return([0, valid_until])
            allow(request_counter).to receive(:get).with(ip_2, interval, logger).and_return([2, valid_until_2])

            allow(ActionDispatch::Request).to receive(:new).and_return(fake_request)
            _, response_headers, _ = middleware.call(unauthenticated_env)
            expect(request_counter).to have_received(:increment).with(ip)
            expect(response_headers['X-RateLimit-Remaining']).to eq('90')
            expect(response_headers['X-RateLimit-Reset']).to eq(valid_until.utc.to_i.to_s)

            allow(ActionDispatch::Request).to receive(:new).and_return(fake_request_2)
            _, response_headers, _ = middleware.call(unauthenticated_env)
            expect(request_counter).to have_received(:increment).with(ip_2)
            expect(response_headers['X-RateLimit-Remaining']).to eq('70')
            expect(response_headers['X-RateLimit-Reset']).to eq(valid_until_2.utc.to_i.to_s)
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
          expect(response_headers).not_to include('X-RateLimit-Remaining')
          expect(status).to eq(200)
          expect(app).to have_received(:call).at_least(:once)
          expect(request_counter).to_not have_received(:get)
          expect(request_counter).to_not have_received(:increment)
        end
      end

      context 'when limit has exceeded' do
        let(:path_info) { '/v2/foo' }
        let(:middleware_env) do
          { 'cf.user_guid' => 'user-id-1', 'PATH_INFO' => path_info }
        end
        before(:each) { allow(request_counter).to receive(:get).and_return([general_limit + 1, Time.now.utc]) }

        it 'returns 429 response' do
          status, _, _ = middleware.call(middleware_env)
          expect(status).to eq(429)
        end

        it 'does not increment the request counter' do
          _, _, _ = middleware.call(middleware_env)
          expect(request_counter).to_not have_received(:increment)
        end

        it 'prevents "X-RateLimit-Remaining" from going lower than zero' do
          allow(request_counter).to receive(:get).and_return([general_limit + 100, Time.now.utc])
          _, response_headers, _ = middleware.call(middleware_env)
          expect(response_headers['X-RateLimit-Remaining']).to eq('0')
        end

        it 'contains the correct headers' do
          valid_until = Time.now.utc
          allow(request_counter).to receive(:get).and_return([general_limit + 1, valid_until])
          error_presenter = instance_double(ErrorPresenter, to_hash: { foo: 'bar' })
          allow(ErrorPresenter).to receive(:new).and_return(error_presenter)

          _, response_headers, _ = middleware.call(middleware_env)
          expect(response_headers['Retry-After']).to eq(valid_until.utc.to_i.to_s)
          expect(response_headers['Content-Type']).to eq('text/plain; charset=utf-8')
          expect(response_headers['Content-Length']).to eq({ foo: 'bar' }.to_json.length.to_s)
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

        context 'when the user is unauthenticated' do
          let(:path_info) { '/v3/foo' }
          let(:unauthenticated_env) { { 'some' => 'env', 'PATH_INFO' => path_info } }

          it 'suggests they log in' do
            allow(request_counter).to receive(:get).and_return([unauthenticated_limit + 1, Time.now.utc])
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
    end

    RSpec.describe RequestCounter do
      let(:request_counter) { RequestCounter.instance }
      let(:reset_interval_in_minutes) { 60 }
      let(:logger) { double('logger', info: nil) }
      let(:user_guid) { 'user-id' }
      let(:user_guid_2) { 'user-id-2' }

      describe 'get' do
        before(:each) do
          Timecop.freeze
          Singleton.__init__(RequestCounter)
        end
        after(:each) do Timecop.return end

        it 'should return next offset valid until interval and 0 requests for a new user' do
          new_valid_until = Time.now.utc.beginning_of_hour + reset_interval_in_minutes.minutes
          expect_any_instance_of(RequestCounter).to receive(:next_reset_interval).and_return(new_valid_until)

          count, valid_until = request_counter.get(user_guid, reset_interval_in_minutes, logger)
          expect(count).to eq(0)
          expect(valid_until).to eq(new_valid_until)
        end

        it 'should return offset valid untils for different users' do
          new_valid_until_1 = Time.now.utc.beginning_of_hour + reset_interval_in_minutes.minutes
          expect_any_instance_of(RequestCounter).to receive(:next_reset_interval).with(user_guid, reset_interval_in_minutes).and_return(new_valid_until_1)
          _, valid_until = request_counter.get(user_guid, reset_interval_in_minutes, logger)
          expect(valid_until).to eq(new_valid_until_1)

          new_valid_until_2 = Time.now.utc.beginning_of_hour + reset_interval_in_minutes.minutes - 5.minutes
          expect_any_instance_of(RequestCounter).to receive(:next_reset_interval).with(user_guid_2, reset_interval_in_minutes).and_return(new_valid_until_2)
          _, valid_until = request_counter.get(user_guid_2, reset_interval_in_minutes, logger)
          expect(valid_until).to eq(new_valid_until_2)
        end

        it 'should return valid until and requests for an existing user' do
          expect_any_instance_of(RequestCounter).to receive(:next_reset_interval).and_return(Time.now.utc.beginning_of_hour + reset_interval_in_minutes.minutes)
          _, original_valid_until = request_counter.get(user_guid, reset_interval_in_minutes, logger)
          request_counter.increment(user_guid)

          Timecop.travel(original_valid_until - 1.minutes) do
            count, valid_until = request_counter.get(user_guid, reset_interval_in_minutes, logger)
            expect(count).to eq(1)
            expect(valid_until).to eq(original_valid_until)
          end
        end

        it 'should return new valid until and 0 requests for an existing user with expired rate limit' do
          expect_any_instance_of(RequestCounter).to receive(:next_reset_interval).and_return(Time.now.utc.beginning_of_hour + reset_interval_in_minutes.minutes)
          _, original_valid_until = request_counter.get(user_guid, reset_interval_in_minutes, logger)
          request_counter.increment(user_guid)

          Timecop.travel(original_valid_until + 1.minutes) do
            new_valid_until = Time.now.utc.beginning_of_hour + reset_interval_in_minutes.minutes
            expect_any_instance_of(RequestCounter).to receive(:next_reset_interval).and_return(new_valid_until)
            count, valid_until = request_counter.get(user_guid, reset_interval_in_minutes, logger)
            expect(count).to eq(0)
            expect(valid_until).to eq(new_valid_until)
            expect(logger).to have_received(:info).with "Resetting request count of 1 for user 'user-id'"
          end
        end
      end
    end
  end
end
