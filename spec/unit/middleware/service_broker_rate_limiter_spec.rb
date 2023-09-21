require 'spec_helper'

module CloudFoundry
  module Middleware
    RSpec.describe ServiceBrokerRateLimiter do
      let(:app) { double(:app) }
      let(:logger) { double }
      let(:path_info) { '/v3/service_instances' }
      let(:user_guid) { SecureRandom.uuid }
      let(:user_env) { { 'cf.user_guid' => user_guid, 'PATH_INFO' => path_info } }
      let(:fake_request) { instance_double(ActionDispatch::Request, fullpath: '/v3/service_instances', method: 'POST') }
      let(:max_concurrent_requests) { 1 }
      let(:broker_timeout) { 60 }
      let(:middleware) do
        ServiceBrokerRateLimiter.new(app, logger: logger, max_concurrent_requests: max_concurrent_requests, broker_timeout_seconds: broker_timeout)
      end

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
          status, = middleware.call(user_env)
          expect(status).to eq(200)
        end

        it 'allows sequential requests' do
          status, = middleware.call(user_env)
          expect(status).to eq(200)
          status, = middleware.call(user_env)
          expect(status).to eq(200)
        end

        it 'does not allow more than the max number of concurrent requests' do
          threads = 2.times.map { Thread.new { Thread.current[:status], = middleware.call(user_env) } }
          statuses = threads.map { |t| t.join[:status] }

          expect(statuses).to include(200)
          expect(statuses).to include(429)
          expect(app).to have_received(:call).once
          expect(logger).to have_received(:info).with("Service broker concurrent rate limit exceeded for user '#{user_guid}'")
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

        describe 'errors' do
          let(:max_concurrent_requests) { 0 }

          context 'when the path is /v2/*' do
            let(:path_info) { '/v2/service_instances' }

            it 'formats the response error in v2 format' do
              Timecop.freeze do
                _, response_headers, body = middleware.call(user_env)
                json_body = JSON.parse(body.first)
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
                json_body = JSON.parse(body.first)
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
      end

      describe 'skipped requests' do
        let(:concurrent_request_counter) { double }
        before(:each) { middleware.instance_variable_set('@concurrent_request_counter', concurrent_request_counter) }

        context 'user is an admin' do
          before do
            allow(VCAP::CloudController::SecurityContext).to receive(:admin?).and_return(true)
          end

          it 'does not rate limit them' do
            middleware.call(user_env)
            expect(concurrent_request_counter).not_to receive(:try_increment?)
            expect(app).to have_received(:call)
          end
        end

        context 'endpoint does not interact with service brokers' do
          let(:fake_request) { instance_double(ActionDispatch::Request, fullpath: '/v3/apps') }

          it 'does not rate limit them' do
            middleware.call(user_env)
            expect(concurrent_request_counter).not_to receive(:try_increment?)
            expect(app).to have_received(:call)
          end
        end

        context 'endpoint does not use included method' do
          let(:fake_request) { instance_double(ActionDispatch::Request, fullpath: '/v3/service_instances', method: 'GET') }

          it 'does not rate limit them' do
            middleware.call(user_env)
            expect(concurrent_request_counter).not_to receive(:try_increment?)
            expect(app).to have_received(:call)
          end
        end
      end
    end

    RSpec.describe ConcurrentRequestCounter do
      store_implementations = []
      store_implementations << :in_memory   # Test the ConcurrentRequestCounter::InMemoryStore
      store_implementations << :mock_redis  # Test the ConcurrentRequestCounter::RedisStore with MockRedis

      store_implementations.each do |store_implementation|
        describe store_implementation do
          let(:concurrent_request_counter) { ConcurrentRequestCounter.new('test') }
          let(:store) { concurrent_request_counter.instance_variable_get(:@store) }
          let(:user_guid) { SecureRandom.uuid }
          let(:max_concurrent_requests) { 5 }
          let(:logger) { double('logger', info: nil) }

          before do
            TestConfig.override(redis: { socket: 'foo' }, puma: { max_threads: 123 }) unless store_implementation == :in_memory

            allow(ConnectionPool::Wrapper).to receive(:new).and_call_original
            concurrent_request_counter.send(:store) # instantiate counter and store implementation
          end

          describe '#initialize' do
            it 'sets the @key_prefix' do
              expect(concurrent_request_counter.instance_variable_get(:@key_prefix)).to eq('test')
            end

            it 'instantiates the appropriate store class' do
              if store_implementation == :in_memory
                expect(store).to be_kind_of(ConcurrentRequestCounter::InMemoryStore)
              else
                expect(store).to be_kind_of(ConcurrentRequestCounter::RedisStore)
              end
            end

            it 'uses a connection pool size that equals the maximum puma threads' do
              skip('Not relevant for InMemoryStore') if store_implementation == :in_memory

              expect(ConnectionPool::Wrapper).to have_received(:new).with(size: 123)
            end

            context 'with custom connection pool size' do
              let(:concurrent_request_counter) { ConcurrentRequestCounter.new('test', redis_connection_pool_size: 456) }

              it 'uses the provided connection pool size' do
                skip('Not relevant for InMemoryStore') if store_implementation == :in_memory

                expect(ConnectionPool::Wrapper).to have_received(:new).with(size: 456)
              end
            end
          end

          describe '#try_increment?' do
            it 'calls @store.try_increment? with the prefixed user guid and the given maximum concurrent requests and logger' do
              allow(store).to receive(:try_increment?).and_call_original
              concurrent_request_counter.try_increment?(user_guid, max_concurrent_requests, logger)
              expect(store).to have_received(:try_increment?).with("test:#{user_guid}", max_concurrent_requests, logger)
            end

            it 'returns true for a new user' do
              expect(concurrent_request_counter.try_increment?(user_guid, max_concurrent_requests, logger)).to be_truthy
            end

            it 'returns true for a recurring user performing the maximum allowed concurrent requests' do
              (max_concurrent_requests - 1).times { concurrent_request_counter.try_increment?(user_guid, max_concurrent_requests, logger) }
              expect(concurrent_request_counter.try_increment?(user_guid, max_concurrent_requests, logger)).to be_truthy
            end

            it 'returns false for a recurring user with too many concurrent requests' do
              max_concurrent_requests.times { concurrent_request_counter.try_increment?(user_guid, max_concurrent_requests, logger) }
              expect(concurrent_request_counter.try_increment?(user_guid, max_concurrent_requests, logger)).to be_falsey
            end

            it 'returns true again for a recurring user after a single decrement' do
              (max_concurrent_requests + 1).times { concurrent_request_counter.try_increment?(user_guid, max_concurrent_requests, logger) }
              concurrent_request_counter.decrement(user_guid, logger)
              expect(concurrent_request_counter.try_increment?(user_guid, max_concurrent_requests, logger)).to be_truthy
            end

            it 'returns true in case of a Redis error' do
              skip('Not relevant for InMemoryStore') if store_implementation == :in_memory

              allow_any_instance_of(MockRedis::StringMethods).to receive(:incr).and_raise(Redis::ConnectionError)
              allow_any_instance_of(Redis).to receive(:incr).and_raise(Redis::ConnectionError)
              allow(logger).to receive(:error)

              expect(concurrent_request_counter.try_increment?(user_guid, max_concurrent_requests, logger)).to be_truthy
              expect(logger).to have_received(:error).with(/Redis error/)
            end
          end

          describe '#decrement' do
            it 'calls @store.decrement with the prefixed user guid and the given logger' do
              allow(store).to receive(:decrement).and_call_original
              concurrent_request_counter.decrement(user_guid, logger)
              expect(store).to have_received(:decrement).with("test:#{user_guid}", logger)
            end

            it 'decreases the number of concurrent requests, allowing for another concurrent request' do
              max_concurrent_requests.times { concurrent_request_counter.try_increment?(user_guid, max_concurrent_requests, logger) }
              concurrent_request_counter.decrement(user_guid, logger)
              expect(concurrent_request_counter.try_increment?(user_guid, max_concurrent_requests, logger)).to be_truthy
            end

            it 'does not decrease the number of concurrent requests below zero' do
              concurrent_request_counter.decrement(user_guid, logger)
              max_concurrent_requests.times { concurrent_request_counter.try_increment?(user_guid, max_concurrent_requests, logger) }
              expect(concurrent_request_counter.try_increment?(user_guid, max_concurrent_requests, logger)).to be_falsey
            end

            it 'writes an error log in case of a Redis error' do
              skip('Not relevant for InMemoryStore') if store_implementation == :in_memory

              allow_any_instance_of(MockRedis::StringMethods).to receive(:decr).and_raise(Redis::ConnectionError)
              allow_any_instance_of(Redis).to receive(:decr).and_raise(Redis::ConnectionError)
              allow(logger).to receive(:error)

              concurrent_request_counter.decrement(user_guid, logger)
              expect(logger).to have_received(:error).with(/Redis error/)
            end
          end
        end
      end
    end
  end
end
