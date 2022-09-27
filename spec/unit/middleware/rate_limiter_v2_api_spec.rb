require 'spec_helper'

module CloudFoundry
  module Middleware
    RSpec.describe RateLimiterV2API do
      let(:middleware) do
        RateLimiterV2API.new(
          app,
          {
            logger:                    logger,
            per_process_general_limit: per_process_general_limit,
            global_general_limit:      global_general_limit,
            per_process_admin_limit:   per_process_admin_limit,
            global_admin_limit:        global_admin_limit,
            interval:                  interval,
          }
        )
      end
      let(:request_counter) { double }
      before(:each) {
        middleware.instance_variable_set('@request_counter', request_counter)
        allow(request_counter).to receive(:get).and_return([0, Time.now.utc])
        allow(request_counter).to receive(:increment)
      }

      let(:app) { double(:app, call: [200, {}, 'a body']) }
      let(:per_process_general_limit) { 20 }
      let(:global_general_limit) { 200 }
      let(:per_process_admin_limit) { 100 }
      let(:global_admin_limit) { 1000 }
      let(:interval) { 60 }
      let(:logger) { double('logger', info: nil) }

      let(:path_info) { '/v2/service_instances' }
      let(:default_env) { { some: 'env' } }
      let(:basic_auth_env) { { 'HTTP_AUTHORIZATION' => ActionController::HttpAuthentication::Basic.encode_credentials('user', 'pass') } }
      let(:user_1_guid) { 'user-id-1' }
      let(:user_2_guid) { 'user-id-2' }
      let(:user_1_env) { { 'cf.user_guid' => user_1_guid, 'PATH_INFO' => path_info } }
      let(:user_2_env) { { 'cf.user_guid' => user_2_guid, 'PATH_INFO' => path_info } }

      describe 'headers as regular user' do
        describe 'X-RateLimit-Limit-V2-API' do
          it 'shows the user the total request limit' do
            _, response_headers, _ = middleware.call(user_1_env)
            expect(response_headers['X-RateLimit-Limit-V2-API']).to eq(global_general_limit.to_s)
          end
        end

        describe 'X-RateLimit-Remaining-V2-API' do
          it 'shows the user the number of remaining requests rounded down to nearest 10%' do
            allow(request_counter).to receive(:get).and_return([0, Time.now.utc])
            _, response_headers, _ = middleware.call(user_1_env)
            expect(response_headers['X-RateLimit-Remaining-V2-API']).to eq('180')

            allow(request_counter).to receive(:get).and_return([10, Time.now.utc])
            _, response_headers, _ = middleware.call(user_1_env)
            expect(response_headers['X-RateLimit-Remaining-V2-API']).to eq('80')
          end

          it "tracks user's remaining requests independently" do
            expect(request_counter).to receive(:get).with(user_1_guid, interval, logger).and_return([0, Time.now.utc])
            expect(request_counter).to receive(:get).with(user_2_guid, interval, logger).and_return([10, Time.now.utc])

            _, response_headers, _ = middleware.call(user_1_env)
            expect(response_headers['X-RateLimit-Remaining-V2-API']).to eq('180')

            _, response_headers, _ = middleware.call(user_2_env)
            expect(response_headers['X-RateLimit-Remaining-V2-API']).to eq('80')
          end
        end

        describe 'X-RateLimit-Reset-V2-API' do
          it 'shows the user when the interval will expire' do
            valid_until = Time.now.utc.beginning_of_hour + interval.minutes
            allow(request_counter).to receive(:get).and_return([0, valid_until])
            _, response_headers, _ = middleware.call(user_1_env)
            expect(response_headers['X-RateLimit-Reset-V2-API'].to_i).to eq(valid_until.utc.to_i)
          end
        end
      end

      describe 'headers as admin user' do
        before do
          allow(VCAP::CloudController::SecurityContext).to receive(:admin_read_only?).and_return(true)
        end
        describe 'X-RateLimit-Limit-V2-API' do
          it 'shows the user the total request limit' do
            _, response_headers, _ = middleware.call(user_1_env)
            expect(response_headers['X-RateLimit-Limit-V2-API']).to eq(global_admin_limit.to_s)
          end
        end

        describe 'X-RateLimit-Remaining-V2-API' do
          it 'shows the user the number of remaining requests rounded down to nearest 10%' do
            allow(request_counter).to receive(:get).and_return([0, Time.now.utc])
            _, response_headers, _ = middleware.call(user_1_env)
            expect(response_headers['X-RateLimit-Remaining-V2-API']).to eq('900')

            allow(request_counter).to receive(:get).and_return([10, Time.now.utc])
            _, response_headers, _ = middleware.call(user_1_env)
            expect(response_headers['X-RateLimit-Remaining-V2-API']).to eq('800')
          end
        end

        describe 'X-RateLimit-Reset-V2-API' do
          it 'shows the user when the interval will expire' do
            valid_until = Time.now.utc.beginning_of_hour + interval.minutes
            allow(request_counter).to receive(:get).and_return([0, valid_until])
            _, response_headers, _ = middleware.call(user_1_env)
            expect(response_headers['X-RateLimit-Reset-V2-API'].to_i).to eq(valid_until.utc.to_i)
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

      describe 'exempting non v2/* endpoints' do
        describe 'exempting internal endpoints' do
          context 'when the user is hitting a path starting with "/internal"' do
            let(:fake_request) { instance_double(ActionDispatch::Request, fullpath: '/internal/pants/1234') }

            it 'exempts them from rate limiting' do
              allow(ActionDispatch::Request).to receive(:new).and_return(fake_request)
              _, response_headers, _ = middleware.call(default_env)
              expect(request_counter).not_to have_received(:get)
              expect(request_counter).not_to have_received(:increment)
              expect(response_headers['X-RateLimit-Limit-V2-API']).to be_nil
              expect(response_headers['X-RateLimit-Remaining-V2-API']).to be_nil
              expect(response_headers['X-RateLimit-Reset-V2-API']).to be_nil
            end
          end

          context 'when the user is hitting containing, but NOT starting with "/internal"' do
            let(:headers) { ActionDispatch::Http::Headers.from_hash({ 'HTTP_X_FORWARDED_FOR' => 'forwarded_ip' }) }
            let(:fake_request) { instance_double(ActionDispatch::Request, fullpath: '/v2/pants/internal/1234', headers: headers) }

            it 'rate limits them' do
              allow(ActionDispatch::Request).to receive(:new).and_return(fake_request)
              expect(request_counter).to receive(:get).with('forwarded_ip', interval, logger).and_return([0, Time.now.utc])
              expect(request_counter).to receive(:increment).with('forwarded_ip')
              _, response_headers, _ = middleware.call(default_env)
              expect(response_headers['X-RateLimit-Limit-V2-API']).to_not be_nil
              expect(response_headers['X-RateLimit-Remaining-V2-API']).to_not be_nil
              expect(response_headers['X-RateLimit-Reset-V2-API']).to_not be_nil
            end
          end
        end

        context 'when the user is hitting a root path /' do
          let(:fake_request) { instance_double(ActionDispatch::Request, fullpath: '/') }

          it_behaves_like 'endpoint exempts from rate limiting', '-V2-API' do
            let(:env) { default_env }
          end
        end

        context 'when the user is hitting a root path /v2/info' do
          let(:fake_request) { instance_double(ActionDispatch::Request, fullpath: '/v2/info') }

          it_behaves_like 'endpoint exempts from rate limiting', '-V2-API' do
            let(:env) { default_env }
          end
        end

        context 'when the user is hitting a root path /v3' do
          let(:fake_request) { instance_double(ActionDispatch::Request, fullpath: '/v3') }

          it_behaves_like 'endpoint exempts from rate limiting', '-V2-API' do
            let(:env) { default_env }
          end
        end

        context 'when the user is hitting a root path /v3/services' do
          let(:fake_request) { instance_double(ActionDispatch::Request, fullpath: '/v3/services') }

          it_behaves_like 'endpoint exempts from rate limiting', '-V2-API' do
            let(:env) { default_env }
          end
        end

        context 'when the user is hitting a root path /healthz' do
          let(:fake_request) { instance_double(ActionDispatch::Request, fullpath: '/healthz') }

          it_behaves_like 'endpoint exempts from rate limiting', '-V2-API' do
            let(:env) { default_env }
          end
        end
      end

      describe 'when the user is not logged in' do
        describe 'when the user has basic auth credentials' do
          it 'exempts them from rate limiting' do
            _, response_headers, _ = middleware.call(basic_auth_env)
            expect(request_counter).not_to have_received(:get)
            expect(request_counter).not_to have_received(:increment)
            expect(response_headers['X-RateLimit-Limit-V2-API']).to be_nil
            expect(response_headers['X-RateLimit-Remaining-V2-API']).to be_nil
            expect(response_headers['X-RateLimit-Reset-V2-API']).to be_nil
          end
        end

        describe 'when the user has a "HTTP_X_FORWARDED_FOR" header from proxy' do
          let(:forwarded_ip) { 'forwarded_ip' }
          let(:forwarded_ip_2) { 'forwarded_ip_2' }
          let(:headers) { ActionDispatch::Http::Headers.from_hash({ 'HTTP_X_FORWARDED_FOR' => forwarded_ip }) }
          let(:headers_2) { ActionDispatch::Http::Headers.from_hash({ 'HTTP_X_FORWARDED_FOR' => forwarded_ip_2 }) }
          let(:fake_request) { instance_double(ActionDispatch::Request, headers: headers, ip: 'proxy-ip', fullpath: '/v2/some/path') }
          let(:fake_request_2) { instance_double(ActionDispatch::Request, headers: headers_2, ip: 'proxy-ip', fullpath: '/v2/some/path') }

          before do
            allow(fake_request).to receive(:fetch_header).with('HTTP_X_FORWARDED_FOR').and_return(forwarded_ip)
            allow(fake_request_2).to receive(:fetch_header).with('HTTP_X_FORWARDED_FOR').and_return(forwarded_ip_2)
          end

          it 'identifies them by the "HTTP_X_FORWARDED_FOR" header' do
            valid_until = Time.now.utc
            valid_until_2 = Time.now.utc

            allow(ActionDispatch::Request).to receive(:new).and_return(fake_request)
            expect(request_counter).to receive(:get).with(forwarded_ip, interval, logger).and_return([0, valid_until])
            expect(request_counter).to receive(:increment).with(forwarded_ip)
            _, response_headers, _ = middleware.call(default_env)
            expect(response_headers['X-RateLimit-Remaining-V2-API']).to eq('180')
            expect(response_headers['X-RateLimit-Reset-V2-API']).to eq(valid_until.to_i.to_s)

            allow(ActionDispatch::Request).to receive(:new).and_return(fake_request_2)
            expect(request_counter).to receive(:get).with(forwarded_ip_2, interval, logger).and_return([2, valid_until_2])
            expect(request_counter).to receive(:increment).with(forwarded_ip_2)
            _, response_headers, _ = middleware.call(default_env)
            expect(response_headers['X-RateLimit-Remaining-V2-API']).to eq('160')
            expect(response_headers['X-RateLimit-Reset-V2-API']).to eq(valid_until_2.to_i.to_s)
          end
        end

        describe 'when the there is no "HTTP_X_FORWARDED_FOR" header' do
          let(:headers) { ActionDispatch::Http::Headers.from_hash({ 'X_HEADER' => 'nope' }) }
          let(:ip) { 'some-ip' }
          let(:ip_2) { 'some-ip-2' }
          let(:fake_request) { instance_double(ActionDispatch::Request, headers: headers, ip: ip, fullpath: '/v2/some/path') }
          let(:fake_request_2) { instance_double(ActionDispatch::Request, headers: headers, ip: ip_2, fullpath: '/v2/some/path') }

          it 'identifies them by the request ip' do
            valid_until = Time.now.utc.beginning_of_hour
            valid_until_2 = Time.now.utc.beginning_of_hour + 5.minutes
            allow(request_counter).to receive(:get).with(ip, interval, logger).and_return([0, valid_until])
            allow(request_counter).to receive(:get).with(ip_2, interval, logger).and_return([2, valid_until_2])

            allow(ActionDispatch::Request).to receive(:new).and_return(fake_request)
            _, response_headers, _ = middleware.call(default_env)
            expect(request_counter).to have_received(:increment).with(ip)
            expect(response_headers['X-RateLimit-Remaining-V2-API']).to eq('180')
            expect(response_headers['X-RateLimit-Reset-V2-API']).to eq(valid_until.utc.to_i.to_s)

            allow(ActionDispatch::Request).to receive(:new).and_return(fake_request_2)
            _, response_headers, _ = middleware.call(default_env)
            expect(request_counter).to have_received(:increment).with(ip_2)
            expect(response_headers['X-RateLimit-Remaining-V2-API']).to eq('160')
            expect(response_headers['X-RateLimit-Reset-V2-API']).to eq(valid_until_2.utc.to_i.to_s)
          end
        end
      end

      context 'when limit has exceeded' do
        let(:path_info) { '/v2/foo' }
        let(:middleware_env) do
          { 'cf.user_guid' => 'user-id-1', 'PATH_INFO' => path_info }
        end
        before(:each) { allow(request_counter).to receive(:get).and_return([per_process_general_limit + 1, Time.now.utc]) }

        it 'returns 429 response' do
          status, _, _ = middleware.call(middleware_env)
          expect(status).to eq(429)
        end

        it 'does not increment the request counter' do
          _, _, _ = middleware.call(middleware_env)
          expect(request_counter).to_not have_received(:increment)
        end

        it 'prevents "X-RateLimit-Remaining-V2-API" from going lower than zero' do
          allow(request_counter).to receive(:get).and_return([per_process_general_limit + 100, Time.now.utc])
          _, response_headers, _ = middleware.call(middleware_env)
          expect(response_headers['X-RateLimit-Remaining-V2-API']).to eq('0')
        end

        it 'contains the correct headers' do
          valid_until = Time.now.utc
          allow(request_counter).to receive(:get).and_return([per_process_general_limit + 1, valid_until])
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

        it 'formats the response error in v2 format' do
          _, _, body = middleware.call(middleware_env)
          json_body = JSON.parse(body.first)
          expect(json_body).to include(
            'code' => 10018,
            'description' => 'Rate Limit of V2 API Exceeded. Please consider to use V3 API',
            'error_code' => 'CF-RateLimitV2APIExceeded',
          )
        end

        context 'when the user is admin' do
          let(:path_info) { '/v2/foo' }
          let(:default_env) { { 'some' => 'env', 'PATH_INFO' => path_info } }

          before do
            allow(VCAP::CloudController::SecurityContext).to receive(:admin_read_only?).and_return(true)
          end

          it 'contains the correct headers' do
            valid_until = Time.now.utc
            allow(request_counter).to receive(:get).and_return([per_process_admin_limit + 1, valid_until])
            error_presenter = instance_double(ErrorPresenter, to_hash: { foo: 'bar' })
            allow(ErrorPresenter).to receive(:new).and_return(error_presenter)

            _, response_headers, _ = middleware.call(middleware_env)
            expect(response_headers['Retry-After']).to eq(valid_until.utc.to_i.to_s)
            expect(response_headers['Content-Type']).to eq('text/plain; charset=utf-8')
            expect(response_headers['Content-Length']).to eq({ foo: 'bar' }.to_json.length.to_s)
          end
        end

        context 'when the user is excluded from rate limits' do
          let(:path_info) { '/v2/foo' }
          let(:default_env) { { 'some' => 'env', 'PATH_INFO' => path_info, 'v2_api_rate_limit_exempt' => 'true' } }

          it 'returns 200 response' do
            status, _, _ = middleware.call(middleware_env)
            expect(status).to eq(200)
          end
        end
      end
    end
  end
end
