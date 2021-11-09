require 'spec_helper'

module CloudFoundry
  module Middleware
    RSpec.describe ServiceBrokerRateLimiter do
      let(:app) { double(:app) }
      let(:logger) { double('logger', info: nil) }
      let(:path_info) { '/v3/service_instances' }
      let(:user_env) { { 'cf.user_guid' => 'user_guid', 'PATH_INFO' => path_info } }
      let(:fake_request) { instance_double(ActionDispatch::Request, fullpath: '/v3/service_instances', method: 'POST') }
      let(:middleware) { ServiceBrokerRateLimiter.new(app, logger: logger, concurrent_limit: 1) }

      before(:each) do
        allow(ActionDispatch::Request).to receive(:new).and_return(fake_request)
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
        end

        it 'still decrements the count when an error occurs in another middleware' do
          allow(app).to receive(:call).and_raise 'an error'
          expect { middleware.call(user_env) }.to raise_error('an error')
          allow(app).to receive(:call).and_return [200, {}, 'a body']
          status, _, _ = middleware.call(user_env)
          expect(status).to eq(200)
        end

        describe 'errors' do
          let(:middleware) { ServiceBrokerRateLimiter.new(app, logger: logger, concurrent_limit: 0) }

          context 'when the path is /v2/*' do
            let(:path_info) { '/v2/service_instances' }
            it 'formats the response error in v2 format' do
              _, _, body = middleware.call(user_env)
              json_body = JSON.parse(body.first)
              expect(json_body).to include(
                'code' => 10016,
                'description' => 'Service broker concurrent request limit exceeded',
                'error_code' => 'CF-ServiceBrokerRateLimitExceeded',
              )
            end
          end

          context 'when the path is /v3/*' do
            let(:path_info) { '/v3/service_instances' }

            it 'formats the response error in v3 format' do
              _, _, body = middleware.call(user_env)
              json_body = JSON.parse(body.first)
              expect(json_body['errors'].first).to include(
                'code' => 10016,
                'detail' => 'Service broker concurrent request limit exceeded',
                'title' => 'CF-ServiceBrokerRateLimitExceeded',
              )
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
            expect(request_counter).not_to receive(:can_make_request?)
            expect(app).to have_received(:call)
          end
        end

        context 'endpoint does not interact with service brokers' do
          let(:fake_request) { instance_double(ActionDispatch::Request, fullpath: '/v3/apps') }

          it 'does not rate limit them' do
            _, _, _ = middleware.call(user_env)
            expect(request_counter).not_to receive(:can_make_request?)
            expect(app).to have_received(:call)
          end
        end

        context 'endpoint does not use included method' do
          let(:fake_request) { instance_double(ActionDispatch::Request, fullpath: '/v3/service_instances', method: 'GET') }

          it 'does not rate limit them' do
            _, _, _ = middleware.call(user_env)
            expect(request_counter).not_to receive(:can_make_request?)
            expect(app).to have_received(:call)
          end
        end
      end
    end
  end
end
