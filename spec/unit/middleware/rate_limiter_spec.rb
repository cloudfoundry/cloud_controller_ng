require 'spec_helper'
require 'request_logs'

module CloudFoundry
  module Middleware
    RSpec.describe RateLimiter do
      let(:middleware) { RateLimiter.new(app, general_limit, interval) }

      let(:app) { double(:app, call: [200, {}, 'a body']) }
      let(:general_limit) { 100 }
      let(:interval) { 60 }

      it 'adds a "X-RateLimit-Limit" header' do
        _, response_headers, _ = middleware.call({ 'cf.user_guid' => 'user-id-1' })
        expect(response_headers['X-RateLimit-Limit']).to eq('100')
      end

      it 'adds a "X-RateLimit-Reset" header per user' do
        Timecop.freeze do
          valid_until            = Time.now + interval.minutes
          _, response_headers, _ = middleware.call({ 'cf.user_guid' => 'user-id-1' })
          expect(response_headers['X-RateLimit-Reset']).to eq(valid_until.utc.to_i.to_s)

          Timecop.travel(Time.now + 30.minutes)

          _, response_headers, _ = middleware.call({ 'cf.user_guid' => 'user-id-1' })
          expect(response_headers['X-RateLimit-Reset']).to eq(valid_until.utc.to_i.to_s)

          Timecop.travel(Time.now + 31.minutes)
          valid_until            = Time.now + 60.minutes
          _, response_headers, _ = middleware.call({ 'cf.user_guid' => 'user-id-1' })
          expect(response_headers['X-RateLimit-Reset']).to eq(valid_until.utc.to_i.to_s)
        end
      end

      it 'adds a "X-RateLimit-Remaining" header per user' do
        _, response_headers, _ = middleware.call({ 'cf.user_guid' => 'user-id-1' })
        expect(response_headers['X-RateLimit-Remaining']).to eq('99')
        _, response_headers, _ = middleware.call({ 'cf.user_guid' => 'user-id-1' })
        expect(response_headers['X-RateLimit-Remaining']).to eq('98')

        _, response_headers, _ = middleware.call({ 'cf.user_guid' => 'user-id-2' })
        expect(response_headers['X-RateLimit-Remaining']).to eq('99')
      end

      it 'resets "X-RateLimit-Remaining" after interval is over' do
        Timecop.freeze do
          _, response_headers, _ = middleware.call({ 'cf.user_guid' => 'user-id-1' })
          expect(response_headers['X-RateLimit-Remaining']).to eq('99')

          Timecop.travel(Time.now + 61.minutes)

          _, response_headers, _ = middleware.call({ 'cf.user_guid' => 'user-id-1' })
          expect(response_headers['X-RateLimit-Remaining']).to eq('99')
        end
      end

      it 'does not add "X-RateLimit-*" headers when the user is not logged it' do
        _, response_headers, _ = middleware.call({})
        expect(response_headers['X-RateLimit-Remaining']).to be_nil
      end

      it 'allows the request to continue' do
        _, _, _ = middleware.call({ 'cf.user_guid' => 'user-id-1' })
        expect(app).to have_received(:call)
      end

      it 'does not drop headers created in next middleware' do
        allow(app).to receive(:call).and_return([200, { 'from' => 'wrapped-app' }, 'a body'])
        _, headers, _ = middleware.call({})
        expect(headers).to match(hash_including('from' => 'wrapped-app'))
      end

      context 'when user has admin or admin_read_only scopes' do
        let(:general_limit) { 1 }

        before do
          allow(VCAP::CloudController::SecurityContext).to receive(:admin_read_only?).and_return(true)
        end
        it 'does not rate limit' do
          _, _, _                     = middleware.call({ 'cf.user_guid' => 'user-id-1' })
          _, _, _                     = middleware.call({ 'cf.user_guid' => 'user-id-1' })
          status, response_headers, _ = middleware.call({ 'cf.user_guid' => 'user-id-1' })
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

            valid_until            = Time.now + interval.minutes
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
        let(:other_middleware) { RateLimiter.new(app, general_limit, interval) }

        it 'shares request count between servers' do
          _, response_headers, _ = middleware.call({ 'cf.user_guid' => 'user-id-1' })
          expect(response_headers['X-RateLimit-Remaining']).to eq('99')
          _, response_headers, _ = other_middleware.call({ 'cf.user_guid' => 'user-id-1' })
          expect(response_headers['X-RateLimit-Remaining']).to eq('98')
        end
      end
    end
  end
end
