require 'spec_helper'

module CloudFoundry
  module Middleware
    RSpec.describe ServiceBrokerRateLimiter, isolation: :truncation do
      let(:app) { double(:app) }
      let(:logger) { double('logger', info: nil) }
      let(:instance) { create(:service, instances_retrievable: true) }
      let(:path_info) { '/v2/service_instances' }
      let(:user_guid) { SecureRandom.uuid }
      let(:user_env) { { 'cf.user_guid' => user_guid, 'PATH_INFO' => path_info } }
      let(:env) { { 'cf.user_guid' => user_guid, 'PATH_INFO' => path, 'REQUEST_METHOD' => request_method } }
      let(:fake_request) { instance_double(ActionDispatch::Request, fullpath: '/v2/service_instances', method: 'POST') }
      let(:max_concurrent_requests) { 1 }
      let(:broker_timeout) { 60 }
      let(:counter) { instance_double(ConcurrentRequestCounter, try_increment?: true, decrement: nil) }

      let(:middleware) do
        ServiceBrokerRateLimiter.new(app, logger: logger, max_concurrent_requests: max_concurrent_requests, broker_timeout_seconds: broker_timeout)
      end

      before do
        allow(ConcurrentRequestCounter).to receive(:instance).and_return(counter)
        allow(ActionDispatch::Request).to receive(:new).and_return(fake_request)
        allow(logger).to receive(:info)
        allow(app).to receive(:call).and_return([200, {}, 'a body'])
      end

      describe 'included requests' do
        let(:fake_request) { instance_double(ActionDispatch::Request, fullpath: '/v2/service_instances', method: 'PUT') }

        it 'allows a service broker request within the limit' do
          status, = middleware.call(user_env)
          expect(status).to eq(200)
        end

        it 'allows sequential requests' do
          status, = middleware.call(user_env)
          expect(status).to eq(200)
          status, = middleware.call(user_env)
          expect(status).to eq(200)
        end

        it 'counts concurrent requests per user' do
          other_user_env = { 'cf.user_guid' => 'other_user_guid', 'PATH_INFO' => path_info }
          threads = [user_env, other_user_env].map do |env|
            Thread.new { Thread.current[:status], = middleware.call(env) }
          end
          statuses = threads.map { |t| t.join[:status] }

          expect(statuses).to include(200)
          expect(statuses).not_to include(429)
          expect(app).to have_received(:call).twice
        end

        it 'still decrements when an error occurs in another middleware' do
          allow(app).to receive(:call).and_raise 'an error'
          expect { middleware.call(user_env) }.to raise_error('an error')
          allow(app).to receive(:call).and_return [200, {}, 'a body']
          status, = middleware.call(user_env)
          expect(status).to eq(200)
        end

        describe 'service endpoints' do
          context 'v2 and v3 rate limited service endpoints' do
            rate_limited_service_endpoints = [
              %w[/v2/service_instances POST],
              %w[/v2/service_bindings POST],
              %w[/v2/service_keys POST],
              %w[/v2/service_instances PUT],
              %w[/v2/service_bindings PUT],
              %w[/v2/service_keys PUT],
              %w[/v2/service_instances DELETE],
              %w[/v2/service_bindings DELETE],
              %w[/v2/service_keys DELETE],
              %w[/v3/service_instances/:guid/parameters GET],
              %w[/v3/service_credential_bindings/:guid/parameters GET],
              %w[/v3/service_route_bindings/:guid/parameters GET]
            ]
            rate_limited_service_endpoints.each do |endpoint, method|
              context "#{endpoint} #{method} - rate-limited" do
                let(:path) { endpoint.gsub(':guid', instance.guid.to_s) }
                let(:request_method) { method }
                let(:fake_request) { instance_double(ActionDispatch::Request, fullpath: endpoint, method: method) }

                before do
                  real_counter = ConcurrentRequestCounter.new('test-service-broker', blocking_limit: max_concurrent_requests)
                  real_counter.instance_variable_set(:@store, ConcurrentRequestCounter::InMemoryStore.new)
                  middleware.instance_variable_set(:@counter, real_counter)
                end

                it 'does not allow more than the max number of concurrent requests' do
                  gate = Queue.new
                  allow(app).to receive(:call) do
                    gate.pop
                    [200, {}, 'a body']
                  end

                  threads = 2.times.map { Thread.new { middleware.call(env) } }

                  Timeout.timeout(5) { Thread.pass until threads.any? { |t| !t.alive? } }
                  gate << :go

                  statuses = threads.map(&:join).map(&:value).map(&:first)

                  expect(statuses).to include(200)
                  expect(statuses).to include(429)
                  expect(app).to have_received(:call).once
                  expect(logger).to have_received(:info).with("Service broker concurrent rate limit exceeded for user '#{user_guid}'")
                end
              end
            end
          end

          context 'v3 non rate limited service endpoints' do
            v3_not_rate_limited_service_endpoints = [
              %w[/v3/service_instances POST],
              %w[/v3/service_credential_bindings POST],
              %w[/v3/service_route_bindings POST],
              %w[/v3/service_instances PATCH],
              %w[/v3/service_credential_bindings PATCH],
              %w[/v3/service_route_bindings PATCH],
              %w[/v3/service_instances DELETE],
              %w[/v3/service_credential_bindings DELETE],
              %w[/v3/service_route_bindings DELETE]
            ]

            v3_not_rate_limited_service_endpoints.each do |endpoint, method|
              context "#{endpoint} #{method} - non-rate-limited" do
                let(:path) { endpoint }
                let(:request_method) { method }
                let(:fake_request) { instance_double(ActionDispatch::Request, fullpath: endpoint, method: method) }

                it 'allows concurrent requests without limits' do
                  threads = 2.times.map { Thread.new { middleware.call(env) } }
                  statuses = threads.map(&:join).map(&:value).map(&:first)

                  expect(statuses).to all(eq(200))
                  expect(app).to have_received(:call).twice
                  expect(logger).not_to have_received(:info)
                end
              end
            end
          end
        end
      end

      describe 'errors' do
        let(:max_concurrent_requests) { 0 }

        before do
          allow(counter).to receive(:try_increment?).and_return(false)
        end

        context 'when the path is /v2/*' do
          let(:path_info) { '/v2/service_instances' }

          it 'formats the response error in v2 format' do
            Timecop.freeze do
              _, response_headers, body = middleware.call(user_env)
              json_body = Oj.load(body.first)
              expect(json_body).to include(
                'code' => 10_016,
                'description' => 'Service broker concurrent request limit exceeded',
                'error_code' => 'CF-ServiceBrokerRateLimitExceeded'
              )
              expect(response_headers['Retry-After'].to_i).to be_between((broker_timeout * 0.5).floor, (broker_timeout * 1.5).ceil)
            end
          end
        end

        context 'when the path is /v3/*' do
          let(:path_info) { '/v3/service_instances' }

          it 'formats the response error in v3 format' do
            Timecop.freeze do
              _, response_headers, body = middleware.call(user_env)
              json_body = Oj.load(body.first)
              expect(json_body['errors'].first).to include(
                'code' => 10_016,
                'detail' => 'Service broker concurrent request limit exceeded',
                'title' => 'CF-ServiceBrokerRateLimitExceeded'
              )
              expect(response_headers['Retry-After'].to_i).to be_between((broker_timeout * 0.5).floor, (broker_timeout * 1.5).ceil)
            end
          end
        end

        context 'when broker_client_timeout_seconds is reduced' do
          let(:broker_timeout) { 3 }

          it 'reduces the suggested delay in the Retry-After header' do
            Timecop.freeze do
              _, response_headers, = middleware.call(user_env)
              expect(response_headers['Retry-After'].to_i).to be_between((broker_timeout * 0.5).floor, (broker_timeout * 1.5).ceil)
            end
          end
        end
      end

      describe 'skipped requests' do
        context 'user is an admin' do
          before do
            allow(VCAP::CloudController::SecurityContext).to receive(:admin?).and_return(true)
          end

          it 'does not rate limit them' do
            middleware.call(user_env)
            expect(counter).not_to have_received(:try_increment?)
            expect(app).to have_received(:call)
          end
        end

        context 'endpoint does not interact with service brokers' do
          let(:fake_request) { instance_double(ActionDispatch::Request, fullpath: '/v3/apps') }

          it 'does not rate limit them' do
            middleware.call(user_env)
            expect(counter).not_to have_received(:try_increment?)
            expect(app).to have_received(:call)
          end
        end

        context 'endpoint does not use included method' do
          let(:fake_request) { instance_double(ActionDispatch::Request, fullpath: '/v3/service_instances', method: 'GET') }

          it 'does not rate limit them' do
            middleware.call(user_env)
            expect(counter).not_to have_received(:try_increment?)
            expect(app).to have_received(:call)
          end
        end
      end
    end
  end
end
