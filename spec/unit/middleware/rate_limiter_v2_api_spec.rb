require 'spec_helper'

module CloudFoundry
  module Middleware
    RSpec.describe RateLimiterV2API do
      let(:middleware) do
        RateLimiterV2API.new(
          app,
          {
            logger:,
            per_process_general_limit:,
            global_general_limit:,
            per_process_admin_limit:,
            global_admin_limit:,
            interval:
          }
        )
      end
      let(:expiring_request_counter) { double }

      let(:app) { double(:app, call: [200, {}, 'a body']) }
      let(:per_process_general_limit) { 20 }
      let(:global_general_limit) { 200 }
      let(:per_process_admin_limit) { 100 }
      let(:global_admin_limit) { 1000 }
      let(:interval) { 60 }
      let(:logger) { double('logger', info: nil) }
      let(:expires_in) { 10.minutes.to_i }

      let(:path_info) { '/v2/service_instances' }
      let(:unauthenticated_env) { { some: 'env' } }
      let(:user_1_guid) { 'user-id-1' }
      let(:user_1_env) { { 'cf.user_guid' => user_1_guid, 'PATH_INFO' => path_info } }

      let(:frozen_time) { Time.utc(2015, 10, 21, 7, 28) + Time.zone_offset('PDT') }
      let(:frozen_epoch) { frozen_time.to_i }

      before do
        middleware.instance_variable_set('@expiring_request_counter', expiring_request_counter)
        allow(expiring_request_counter).to receive(:increment).and_return([1, expires_in])
        Timecop.freeze frozen_time
      end

      after do
        Timecop.return
      end

      describe 'headers as regular user' do
        describe 'X-RateLimit-Limit-V2-API' do
          it 'shows the user the total request limit' do
            _, response_headers, = middleware.call(user_1_env)
            expect(response_headers['X-RateLimit-Limit-V2-API']).to eq(global_general_limit.to_s)
          end
        end

        describe 'X-RateLimit-Remaining-V2-API' do
          let(:user_2_guid) { 'user-id-2' }
          let(:user_2_env) { { 'cf.user_guid' => user_2_guid, 'PATH_INFO' => path_info } }

          it 'shows the user the number of remaining requests rounded down to nearest 10%' do
            _, response_headers, = middleware.call(user_1_env)
            expect(response_headers['X-RateLimit-Remaining-V2-API']).to eq('180')

            allow(expiring_request_counter).to receive(:increment).and_return([11, expires_in])
            _, response_headers, = middleware.call(user_1_env)
            expect(response_headers['X-RateLimit-Remaining-V2-API']).to eq('80')
          end

          it "tracks user's remaining requests independently" do
            expect(expiring_request_counter).to receive(:increment).with(user_1_guid, interval, logger).and_return([1, expires_in])
            expect(expiring_request_counter).to receive(:increment).with(user_2_guid, interval, logger).and_return([11, expires_in])

            _, response_headers, = middleware.call(user_1_env)
            expect(response_headers['X-RateLimit-Remaining-V2-API']).to eq('180')

            _, response_headers, = middleware.call(user_2_env)
            expect(response_headers['X-RateLimit-Remaining-V2-API']).to eq('80')
          end
        end

        describe 'X-RateLimit-Reset-V2-API' do
          it 'shows the user when the interval will expire' do
            _, response_headers, = middleware.call(user_1_env)
            expect(response_headers['X-RateLimit-Reset-V2-API']).to eq((frozen_epoch + expires_in).to_s)
          end
        end
      end

      it 'increments the counter and allows the request to continue' do
        middleware.call(user_1_env)
        expect(expiring_request_counter).to have_received(:increment).with(user_1_guid, interval, logger)
        expect(app).to have_received(:call)
      end

      it 'does not drop headers created in next middleware' do
        allow(app).to receive(:call).and_return([200, { 'from' => 'wrapped-app' }, 'a body'])
        _, headers, = middleware.call(user_1_env)
        expect(headers).to match(hash_including('from' => 'wrapped-app'))
      end

      describe 'when the user is not logged in' do
        let(:expires_in_2) { expires_in + 5.minutes.to_i }

        describe 'when the user has basic auth credentials' do
          let(:basic_auth_env) { { 'HTTP_AUTHORIZATION' => ActionController::HttpAuthentication::Basic.encode_credentials('user', 'pass') } }

          it_behaves_like 'exempted from rate limiting', '-V2-API' do
            let(:env) { basic_auth_env }
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
            allow(ActionDispatch::Request).to receive(:new).and_return(fake_request)
            expect(expiring_request_counter).to receive(:increment).with(forwarded_ip, interval, logger).and_return([1, expires_in])
            _, response_headers, = middleware.call(unauthenticated_env)
            expect(response_headers['X-RateLimit-Remaining-V2-API']).to eq('180')
            expect(response_headers['X-RateLimit-Reset-V2-API']).to eq((frozen_epoch + expires_in).to_s)

            allow(ActionDispatch::Request).to receive(:new).and_return(fake_request_2)
            expect(expiring_request_counter).to receive(:increment).with(forwarded_ip_2, interval, logger).and_return([3, expires_in_2])
            _, response_headers, = middleware.call(unauthenticated_env)
            expect(response_headers['X-RateLimit-Remaining-V2-API']).to eq('160')
            expect(response_headers['X-RateLimit-Reset-V2-API']).to eq((frozen_epoch + expires_in_2).to_s)
          end
        end

        describe 'when there is no "HTTP_X_FORWARDED_FOR" header' do
          let(:headers) { ActionDispatch::Http::Headers.from_hash({ 'X_HEADER' => 'nope' }) }
          let(:ip) { 'some-ip' }
          let(:ip_2) { 'some-ip-2' }
          let(:fake_request) { instance_double(ActionDispatch::Request, headers: headers, ip: ip, fullpath: '/v2/some/path') }
          let(:fake_request_2) { instance_double(ActionDispatch::Request, headers: headers, ip: ip_2, fullpath: '/v2/some/path') }

          it 'identifies them by the request ip' do
            allow(ActionDispatch::Request).to receive(:new).and_return(fake_request)
            expect(expiring_request_counter).to receive(:increment).with(ip, interval, logger).and_return([1, expires_in])
            _, response_headers, = middleware.call(unauthenticated_env)
            expect(response_headers['X-RateLimit-Remaining-V2-API']).to eq('180')
            expect(response_headers['X-RateLimit-Reset-V2-API']).to eq((frozen_epoch + expires_in).to_s)

            allow(ActionDispatch::Request).to receive(:new).and_return(fake_request_2)
            expect(expiring_request_counter).to receive(:increment).with(ip_2, interval, logger).and_return([3, expires_in_2])
            _, response_headers, = middleware.call(unauthenticated_env)
            expect(response_headers['X-RateLimit-Remaining-V2-API']).to eq('160')
            expect(response_headers['X-RateLimit-Reset-V2-API']).to eq((frozen_epoch + expires_in_2).to_s)
          end
        end
      end

      describe 'headers as admin user' do
        before do
          allow(VCAP::CloudController::SecurityContext).to receive(:admin_read_only?).and_return(true)
        end

        describe 'X-RateLimit-Limit-V2-API' do
          it 'shows the user the total request limit' do
            _, response_headers, = middleware.call(user_1_env)
            expect(response_headers['X-RateLimit-Limit-V2-API']).to eq(global_admin_limit.to_s)
          end
        end

        describe 'X-RateLimit-Remaining-V2-API' do
          it 'shows the user the number of remaining requests rounded down to nearest 10%' do
            _, response_headers, = middleware.call(user_1_env)
            expect(response_headers['X-RateLimit-Remaining-V2-API']).to eq('900')

            allow(expiring_request_counter).to receive(:increment).and_return([11, expires_in])
            _, response_headers, = middleware.call(user_1_env)
            expect(response_headers['X-RateLimit-Remaining-V2-API']).to eq('800')
          end
        end

        describe 'X-RateLimit-Reset-V2-API' do
          it 'shows the user when the interval will expire' do
            _, response_headers, = middleware.call(user_1_env)
            expect(response_headers['X-RateLimit-Reset-V2-API']).to eq((frozen_epoch + expires_in).to_s)
          end
        end
      end

      describe "when the user has the 'cloud_controller.v2_api_rate_limit_exempt' scope" do
        before do
          allow(VCAP::CloudController::SecurityContext).to receive(:v2_rate_limit_exempted?).and_return(true)
        end

        it_behaves_like 'exempted from rate limiting', '-V2-API' do
          let(:env) { user_1_env }
        end
      end

      describe 'exempting non v2/* endpoints' do
        context 'when the user is hitting the /v3/service_instances path' do
          let(:fake_request) { instance_double(ActionDispatch::Request, fullpath: '/v3/service_instances') }

          it_behaves_like 'exempted from rate limiting', '-V2-API' do
            let(:env) { user_1_env }
          end
        end

        describe 'exempting internal endpoints' do
          context 'when the user is hitting a path starting with "/internal"' do
            let(:fake_request) { instance_double(ActionDispatch::Request, fullpath: '/internal/pants/1234') }

            it_behaves_like 'exempted from rate limiting', '-V2-API' do
              let(:env) { user_1_env }
            end
          end

          context 'when the user is hitting a path containing, but NOT starting with "/internal"' do
            let(:headers) { ActionDispatch::Http::Headers.from_hash({ 'HTTP_X_FORWARDED_FOR' => 'forwarded_ip' }) }
            let(:fake_request) { instance_double(ActionDispatch::Request, fullpath: '/v2/pants/internal/1234', headers: headers) }

            it 'rate limits them' do
              allow(ActionDispatch::Request).to receive(:new).and_return(fake_request)
              expect(expiring_request_counter).to receive(:increment).with('forwarded_ip', interval, logger).and_return([0, expires_in])
              _, response_headers, = middleware.call(unauthenticated_env)
              expect(response_headers['X-RateLimit-Limit-V2-API']).not_to be_nil
              expect(response_headers['X-RateLimit-Remaining-V2-API']).not_to be_nil
              expect(response_headers['X-RateLimit-Reset-V2-API']).not_to be_nil
            end
          end
        end

        describe 'exempting root endpoints' do
          context 'when the user is hitting the / path' do
            let(:fake_request) { instance_double(ActionDispatch::Request, fullpath: '/') }

            it_behaves_like 'exempted from rate limiting', '-V2-API' do
              let(:env) { user_1_env }
            end
          end

          context 'when the user is hitting the /v2/info path' do
            let(:fake_request) { instance_double(ActionDispatch::Request, fullpath: '/v2/info') }

            it_behaves_like 'exempted from rate limiting', '-V2-API' do
              let(:env) { user_1_env }
            end
          end

          context 'when the user is hitting the /v3 path' do
            let(:fake_request) { instance_double(ActionDispatch::Request, fullpath: '/v3') }

            it_behaves_like 'exempted from rate limiting', '-V2-API' do
              let(:env) { user_1_env }
            end
          end

          context 'when the user is hitting the /healthz path' do
            let(:fake_request) { instance_double(ActionDispatch::Request, fullpath: '/healthz') }

            it_behaves_like 'exempted from rate limiting', '-V2-API' do
              let(:env) { user_1_env }
            end
          end
        end
      end

      context 'when limit has exceeded' do
        let(:path_info) { '/v2/foo' }

        before do
          allow(expiring_request_counter).to receive(:increment).and_return([per_process_general_limit + 1, expires_in])
        end

        it 'returns 429 response' do
          status, = middleware.call(user_1_env)
          expect(status).to eq(429)
        end

        it 'prevents "X-RateLimit-Remaining-V2-API" from going lower than zero' do
          allow(expiring_request_counter).to receive(:increment).and_return([per_process_general_limit + 100, expires_in])
          _, response_headers, = middleware.call(user_1_env)
          expect(response_headers['X-RateLimit-Remaining-V2-API']).to eq('0')
        end

        it 'contains the correct headers' do
          error_presenter = instance_double(ErrorPresenter, to_hash: { foo: 'bar' })
          allow(ErrorPresenter).to receive(:new).and_return(error_presenter)
          _, response_headers, = middleware.call(user_1_env)
          expect(response_headers['Retry-After']).to eq(expires_in.to_s)
          expect(response_headers['Content-Type']).to eq('text/plain; charset=utf-8')
          expect(response_headers['Content-Length']).to eq({ foo: 'bar' }.to_json.length.to_s)
        end

        it 'ends the request' do
          middleware.call(user_1_env)
          expect(app).not_to have_received(:call)
        end

        it 'formats the response error in v2 format' do
          _, _, body = middleware.call(user_1_env)
          json_body = Oj.load(body.first)
          expect(json_body).to include(
            'code' => 10_018,
            'description' => 'Rate Limit of V2 API Exceeded. Please consider using the V3 API',
            'error_code' => 'CF-RateLimitV2APIExceeded'
          )
        end

        context 'when the user is admin' do
          before do
            allow(VCAP::CloudController::SecurityContext).to receive(:admin_read_only?).and_return(true)
          end

          it 'contains the correct headers' do
            allow(expiring_request_counter).to receive(:increment).and_return([per_process_admin_limit + 1, expires_in])
            error_presenter = instance_double(ErrorPresenter, to_hash: { foo: 'bar' })
            allow(ErrorPresenter).to receive(:new).and_return(error_presenter)

            _, response_headers, = middleware.call(user_1_env)
            expect(response_headers['Retry-After']).to eq(expires_in.to_s)
            expect(response_headers['Content-Type']).to eq('text/plain; charset=utf-8')
            expect(response_headers['Content-Length']).to eq({ foo: 'bar' }.to_json.length.to_s)
          end
        end

        context 'when the user is exempted from rate limiting' do
          before do
            allow(VCAP::CloudController::SecurityContext).to receive(:v2_rate_limit_exempted?).and_return(true)
          end

          it 'returns 200 response' do
            status, = middleware.call(user_1_env)
            expect(status).to eq(200)
          end
        end
      end
    end
  end
end
