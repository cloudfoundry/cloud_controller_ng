require 'spec_helper'

module CloudFoundry
  module Middleware
    RSpec.describe RateLimiter do
      let(:middleware) do
        RateLimiter.new(
          app,
          {
            logger:                            logger,
            per_process_general_limit:         per_process_general_limit,
            global_general_limit:              global_general_limit,
            per_process_unauthenticated_limit: per_process_unauthenticated_limit,
            global_unauthenticated_limit:      global_unauthenticated_limit,
            interval:                          interval,
          }
        )
      end
      let(:expiring_request_counter) { double }

      let(:app) { double(:app, call: [200, {}, 'a body']) }
      let(:per_process_general_limit) { 100 }
      let(:global_general_limit) { 1000 }
      let(:per_process_unauthenticated_limit) { 10 }
      let(:global_unauthenticated_limit) { 100 }
      let(:interval) { 60 }
      let(:logger) { double('logger', info: nil) }
      let(:expires_in) { 10.minutes.to_i }

      let(:unauthenticated_env) { { some: 'env' } }
      let(:user_1_guid) { 'user-id-1' }
      let(:user_1_env) { { 'cf.user_guid' => user_1_guid } }

      let(:frozen_time) { Time.utc(2015, 10, 21, 7, 28) + Time.zone_offset('PDT') }
      let(:frozen_epoch) { frozen_time.to_i }

      before(:each) do
        middleware.instance_variable_set('@expiring_request_counter', expiring_request_counter)
        allow(expiring_request_counter).to receive(:increment).and_return([1, expires_in])
        Timecop.freeze frozen_time
      end

      after(:each) do
        Timecop.return
      end

      describe 'headers' do
        describe 'X-RateLimit-Limit' do
          it 'shows the user the total request limit' do
            _, response_headers, _ = middleware.call(user_1_env)
            expect(response_headers['X-RateLimit-Limit']).to eq(global_general_limit.to_s)
          end
        end

        describe 'X-RateLimit-Remaining' do
          let(:user_2_guid) { 'user-id-2' }
          let(:user_2_env) { { 'cf.user_guid' => user_2_guid } }

          it 'shows the user the number of remaining requests rounded down to nearest 10%' do
            _, response_headers, _ = middleware.call(user_1_env)
            expect(response_headers['X-RateLimit-Remaining']).to eq('900')

            allow(expiring_request_counter).to receive(:increment).and_return([11, expires_in])
            _, response_headers, _ = middleware.call(user_1_env)
            expect(response_headers['X-RateLimit-Remaining']).to eq('800')
          end

          it "tracks user's remaining requests independently" do
            expect(expiring_request_counter).to receive(:increment).with(user_1_guid, interval, logger).and_return([1, expires_in])
            expect(expiring_request_counter).to receive(:increment).with(user_2_guid, interval, logger).and_return([11, expires_in])

            _, response_headers, _ = middleware.call(user_1_env)
            expect(response_headers['X-RateLimit-Remaining']).to eq('900')

            _, response_headers, _ = middleware.call(user_2_env)
            expect(response_headers['X-RateLimit-Remaining']).to eq('800')
          end
        end

        describe 'X-RateLimit-Reset' do
          it 'shows the user when the interval will expire' do
            _, response_headers, _ = middleware.call(user_1_env)
            expect(response_headers['X-RateLimit-Reset']).to eq((frozen_epoch + expires_in).to_s)
          end
        end
      end

      it 'increments the counter and allows the request to continue' do
        _, _, _ = middleware.call(user_1_env)
        expect(expiring_request_counter).to have_received(:increment).with(user_1_guid, interval, logger)
        expect(app).to have_received(:call)
      end

      it 'does not drop headers created in next middleware' do
        allow(app).to receive(:call).and_return([200, { 'from' => 'wrapped-app' }, 'a body'])
        _, headers, _ = middleware.call(user_1_env)
        expect(headers).to match(hash_including('from' => 'wrapped-app'))
      end

      describe 'when the user is not logged in' do
        let(:expires_in_2) { expires_in + 5.minutes.to_i }

        describe 'when the user has basic auth credentials' do
          let(:basic_auth_env) { { 'HTTP_AUTHORIZATION' => ActionController::HttpAuthentication::Basic.encode_credentials('user', 'pass') } }

          it_behaves_like 'exempted from rate limiting' do
            let(:env) { basic_auth_env }
          end
        end

        describe 'exempting internal endpoints' do
          context 'when the user is hitting a path starting with "/internal"' do
            let(:fake_request) { instance_double(ActionDispatch::Request, fullpath: '/internal/pants/1234') }

            it_behaves_like 'exempted from rate limiting' do
              let(:env) { unauthenticated_env }
            end
          end

          context 'when the user is hitting a path containing, but NOT starting with "/internal"' do
            let(:headers) { ActionDispatch::Http::Headers.from_hash({ 'HTTP_X_FORWARDED_FOR' => 'forwarded_ip' }) }
            let(:fake_request) { instance_double(ActionDispatch::Request, fullpath: '/pants/internal/1234', headers: headers) }

            it 'rate limits them' do
              allow(ActionDispatch::Request).to receive(:new).and_return(fake_request)
              expect(expiring_request_counter).to receive(:increment).with('forwarded_ip', interval, logger).and_return([0, expires_in])
              _, response_headers, _ = middleware.call(unauthenticated_env)
              expect(response_headers['X-RateLimit-Limit']).to_not be_nil
              expect(response_headers['X-RateLimit-Remaining']).to_not be_nil
              expect(response_headers['X-RateLimit-Reset']).to_not be_nil
            end
          end
        end

        describe 'exempting root endpoints' do
          context 'when the user is hitting the / path' do
            let(:fake_request) { instance_double(ActionDispatch::Request, fullpath: '/') }

            it_behaves_like 'exempted from rate limiting' do
              let(:env) { unauthenticated_env }
            end
          end

          context 'when the user is hitting the /v2/info path' do
            let(:fake_request) { instance_double(ActionDispatch::Request, fullpath: '/v2/info') }

            it_behaves_like 'exempted from rate limiting' do
              let(:env) { unauthenticated_env }
            end
          end

          context 'when the user is hitting the /v3 path' do
            let(:fake_request) { instance_double(ActionDispatch::Request, fullpath: '/v3') }

            it_behaves_like 'exempted from rate limiting' do
              let(:env) { unauthenticated_env }
            end
          end

          context 'when the user is hitting the /healthz path' do
            let(:fake_request) { instance_double(ActionDispatch::Request, fullpath: '/healthz') }

            it_behaves_like 'exempted from rate limiting' do
              let(:env) { unauthenticated_env }
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
            expect(response_headers['X-RateLimit-Limit']).to eq(global_unauthenticated_limit.to_s)
          end

          it 'identifies them by the "HTTP_X_FORWARDED_FOR" header' do
            allow(ActionDispatch::Request).to receive(:new).and_return(fake_request)
            expect(expiring_request_counter).to receive(:increment).with(forwarded_ip, interval, logger).and_return([1, expires_in])
            _, response_headers, _ = middleware.call(unauthenticated_env)
            expect(response_headers['X-RateLimit-Remaining']).to eq('90')
            expect(response_headers['X-RateLimit-Reset']).to eq((frozen_epoch + expires_in).to_s)

            allow(ActionDispatch::Request).to receive(:new).and_return(fake_request_2)
            expect(expiring_request_counter).to receive(:increment).with(forwarded_ip_2, interval, logger).and_return([3, expires_in_2])
            _, response_headers, _ = middleware.call(unauthenticated_env)
            expect(response_headers['X-RateLimit-Remaining']).to eq('70')
            expect(response_headers['X-RateLimit-Reset']).to eq((frozen_epoch + expires_in_2).to_s)
          end
        end

        describe 'when there is no "HTTP_X_FORWARDED_FOR" header' do
          let(:headers) { ActionDispatch::Http::Headers.from_hash({ 'X_HEADER' => 'nope' }) }
          let(:ip) { 'some-ip' }
          let(:ip_2) { 'some-ip-2' }
          let(:fake_request) { instance_double(ActionDispatch::Request, headers: headers, ip: ip, fullpath: '/some/path') }
          let(:fake_request_2) { instance_double(ActionDispatch::Request, headers: headers, ip: ip_2, fullpath: '/some/path') }

          it 'uses unauthenticated_limit instead of general_limit' do
            allow(ActionDispatch::Request).to receive(:new).and_return(fake_request)
            _, response_headers, _ = middleware.call(unauthenticated_env)
            expect(response_headers['X-RateLimit-Limit']).to eq(global_unauthenticated_limit.to_s)
          end

          it 'identifies them by the request ip' do
            allow(ActionDispatch::Request).to receive(:new).and_return(fake_request)
            expect(expiring_request_counter).to receive(:increment).with(ip, interval, logger).and_return([1, expires_in])
            _, response_headers, _ = middleware.call(unauthenticated_env)
            expect(response_headers['X-RateLimit-Remaining']).to eq('90')
            expect(response_headers['X-RateLimit-Reset']).to eq((frozen_epoch + expires_in).to_s)

            allow(ActionDispatch::Request).to receive(:new).and_return(fake_request_2)
            expect(expiring_request_counter).to receive(:increment).with(ip_2, interval, logger).and_return([3, expires_in_2])
            _, response_headers, _ = middleware.call(unauthenticated_env)
            expect(response_headers['X-RateLimit-Remaining']).to eq('70')
            expect(response_headers['X-RateLimit-Reset']).to eq((frozen_epoch + expires_in_2).to_s)
          end
        end
      end

      context 'when user has admin or admin_read_only scopes' do
        let(:per_process_general_limit) { 1 }

        before do
          allow(VCAP::CloudController::SecurityContext).to receive(:admin_read_only?).and_return(true)
        end

        it 'does not rate limit' do
          2.times { middleware.call(user_1_env) }
          status, response_headers, _ = middleware.call(user_1_env)
          expect(response_headers).not_to include('X-RateLimit-Remaining')
          expect(status).to eq(200)
          expect(app).to have_received(:call).at_least(:once)
          expect(expiring_request_counter).to_not have_received(:increment)
        end
      end

      context 'when limit has exceeded' do
        let(:path_info) { '/v3/foo' }
        let(:user_1_env) { { 'cf.user_guid' => 'user-id-1', 'PATH_INFO' => path_info } }

        before(:each) do
          allow(expiring_request_counter).to receive(:increment).and_return([per_process_general_limit + 1, expires_in])
        end

        it 'returns 429 response' do
          status, _, _ = middleware.call(user_1_env)
          expect(status).to eq(429)
        end

        it 'prevents "X-RateLimit-Remaining" from going lower than zero' do
          allow(expiring_request_counter).to receive(:increment).and_return([per_process_general_limit + 100, expires_in])
          _, response_headers, _ = middleware.call(user_1_env)
          expect(response_headers['X-RateLimit-Remaining']).to eq('0')
        end

        it 'contains the correct headers' do
          error_presenter = instance_double(ErrorPresenter, to_hash: { foo: 'bar' })
          allow(ErrorPresenter).to receive(:new).and_return(error_presenter)
          _, response_headers, _ = middleware.call(user_1_env)
          expect(response_headers['Retry-After']).to eq(expires_in.to_s)
          expect(response_headers['Content-Type']).to eq('text/plain; charset=utf-8')
          expect(response_headers['Content-Length']).to eq({ foo: 'bar' }.to_json.length.to_s)
        end

        it 'ends the request' do
          _, _, _ = middleware.call(user_1_env)
          expect(app).not_to have_received(:call)
        end

        context 'when the path is /v2/*' do
          let(:path_info) { '/v2/foo' }

          it 'formats the response error in v2 format' do
            _, _, body = middleware.call(user_1_env)
            json_body = JSON.parse(body.first)
            expect(json_body).to include(
              'code' => 10013,
              'description' => 'Rate Limit Exceeded',
              'error_code' => 'CF-RateLimitExceeded',
            )
          end
        end

        context 'when the path is /v3/*' do
          it 'formats the response error in v3 format' do
            _, _, body = middleware.call(user_1_env)
            json_body = JSON.parse(body.first)
            expect(json_body['errors'].first).to include(
              'code' => 10013,
              'detail' => 'Rate Limit Exceeded',
              'title' => 'CF-RateLimitExceeded',
            )
          end
        end

        context 'when the user is unauthenticated' do
          let(:unauthenticated_env) { { 'some' => 'env', 'PATH_INFO' => path_info } }

          it 'suggests they log in' do
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

    RSpec.describe ExpiringRequestCounter do
      let(:expiring_request_counter) { ExpiringRequestCounter.new('test') }
      let(:stubbed_expires_in) { 30.minutes.to_i }
      let(:user_guid) { SecureRandom.uuid }
      let(:reset_interval_in_minutes) { 60 }
      let(:logger) { double('logger') }

      before do
        allow(expiring_request_counter).to receive(:next_expires_in).and_return(stubbed_expires_in)
      end

      describe '#initialize' do
        it 'sets the @key_prefix' do
          expect(expiring_request_counter.instance_variable_get(:@key_prefix)).to eq('test')
        end
      end

      describe '#increment' do
        it 'calls next_expires_in with the given user guid and reset interval' do
          expiring_request_counter.increment(user_guid, reset_interval_in_minutes, logger)
          expect(expiring_request_counter).to have_received(:next_expires_in).with(user_guid, reset_interval_in_minutes)
        end

        it 'returns count=1 and expires_in for a new user' do
          count, expires_in = expiring_request_counter.increment(user_guid, reset_interval_in_minutes, logger)
          expect(count).to eq(1)
          expect(expires_in).to eq(stubbed_expires_in)
        end

        it 'returns count=2 and expires_in minus the elapsed time for a recurring user' do
          expiring_request_counter.increment(user_guid, reset_interval_in_minutes, logger)

          elapsed_seconds = 10
          Timecop.travel(Time.now + elapsed_seconds.seconds) do
            count, expires_in = expiring_request_counter.increment(user_guid, reset_interval_in_minutes, logger)
            expect(count).to eq(2)
            expect(expires_in).to eq(stubbed_expires_in - elapsed_seconds)
          end
        end
      end
    end
  end
end
