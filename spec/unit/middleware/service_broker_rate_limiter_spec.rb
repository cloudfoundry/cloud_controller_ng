require 'spec_helper'

module CloudFoundry
  module Middleware
    RSpec.describe ServiceBrokerRateLimiter do
      let(:app) { double(:app) }
      let(:logger) { double }
      let(:path_info) { '/v3/service_instances' }
      let(:user_env) { { 'cf.user_guid' => 'user_guid', 'PATH_INFO' => path_info } }
      let(:fake_request) { instance_double(ActionDispatch::Request, fullpath: '/v3/service_instances', method: 'POST') }
      let(:concurrent_limit) { 1 }
      let(:broker_timeout) { 60 }
      let(:middleware) {
        ServiceBrokerRequestCounter.instance.limit = concurrent_limit
        ServiceBrokerRateLimiter.new(app, logger: logger, broker_timeout_seconds: broker_timeout)
      }

      before(:each) do
        allow(ActionDispatch::Request).to receive(:new).and_return(fake_request)
        allow(logger).to receive(:info)
        allow(app).to receive(:call) do
          sleep(1)
          [200, {}, 'a body']
        end
      end

      describe 'included requests' do
        it 'allows a service broker request within the limit' do
          status, _, _ = middleware.call(user_env)
          expect(status).to eq(200)
        end

        it 'allows sequential requests' do
          status, _, _ = middleware.call(user_env)
          expect(status).to eq(200)
          status, _, _ = middleware.call(user_env)
          expect(status).to eq(200)
        end

        it 'does not allow more than the max number of concurrent requests' do
          threads = 2.times.map { Thread.new { Thread.current[:status], _, _ = middleware.call(user_env) } }
          statuses = threads.map { |t| t.join[:status] }

          expect(statuses).to include(200)
          expect(statuses).to include(429)
          expect(app).to have_received(:call).once
          expect(logger).to have_received(:info).with "Service broker concurrent rate limit exceeded for user 'user_guid'"
        end

        it 'still releases when an error occurs in another middleware' do
          allow(app).to receive(:call).and_raise 'an error'
          expect { middleware.call(user_env) }.to raise_error('an error')
          allow(app).to receive(:call).and_return [200, {}, 'a body']
          status, _, _ = middleware.call(user_env)
          expect(status).to eq(200)
        end

        describe 'errors' do
          let(:concurrent_limit) { 0 }

          context 'when the path is /v2/*' do
            let(:path_info) { '/v2/service_instances' }
            it 'formats the response error in v2 format' do
              Timecop.freeze do
                _, response_headers, body = middleware.call(user_env)
                json_body = JSON.parse(body.first)
                expect(json_body).to include(
                  'code' => 10016,
                  'description' => 'Service broker concurrent request limit exceeded',
                  'error_code' => 'CF-ServiceBrokerRateLimitExceeded',
                )
                expect(response_headers['Retry-After']).to be_between(Time.now + (broker_timeout * 0.5).floor, Time.now + (broker_timeout * 1.5).ceil)
              end
            end
          end

          context 'when the path is /v3/*' do
            let(:path_info) { '/v3/service_instances' }

            it 'formats the response error in v3 format' do
              Timecop.freeze do
                _, response_headers, body = middleware.call(user_env)
                json_body = JSON.parse(body.first)
                expect(json_body['errors'].first).to include(
                  'code' => 10016,
                  'detail' => 'Service broker concurrent request limit exceeded',
                  'title' => 'CF-ServiceBrokerRateLimitExceeded',
                )
                expect(response_headers['Retry-After']).to be_between(Time.now + (broker_timeout * 0.5).floor, Time.now + (broker_timeout * 1.5).ceil)
              end
            end
          end

          context 'when broker_client_timeout_seconds is reduced' do
            let(:broker_timeout) { 3 }
            let(:middleware) {
              ServiceBrokerRequestCounter.instance.limit = concurrent_limit
              ServiceBrokerRateLimiter.new(app, logger: logger, broker_timeout_seconds: broker_timeout)
            }

            it 'reduces the suggested delay in the Retry-After header' do
              Timecop.freeze do
                _, response_headers, _ = middleware.call(user_env)
                expect(response_headers['Retry-After']).to be_between(Time.now + (broker_timeout * 0.5).floor, Time.now + (broker_timeout * 1.5).ceil)
              end
            end
          end
        end
      end

      describe 'skipped requests' do
        let(:request_counter) { double }
        before(:each) { middleware.instance_variable_set('@request_counter', request_counter) }

        context 'user is an admin' do
          before do
            allow(VCAP::CloudController::SecurityContext).to receive(:admin?).and_return(true)
          end

          it 'does not rate limit them' do
            _, _, _ = middleware.call(user_env)
            expect(request_counter).not_to receive(:try_acquire?)
            expect(app).to have_received(:call)
          end
        end

        context 'endpoint does not interact with service brokers' do
          let(:fake_request) { instance_double(ActionDispatch::Request, fullpath: '/v3/apps') }

          it 'does not rate limit them' do
            _, _, _ = middleware.call(user_env)
            expect(request_counter).not_to receive(:try_acquire?)
            expect(app).to have_received(:call)
          end
        end

        context 'endpoint does not use included method' do
          let(:fake_request) { instance_double(ActionDispatch::Request, fullpath: '/v3/service_instances', method: 'GET') }

          it 'does not rate limit them' do
            _, _, _ = middleware.call(user_env)
            expect(request_counter).not_to receive(:try_acquire?)
            expect(app).to have_received(:call)
          end
        end
      end
    end
  end
end
