require 'spec_helper'

module CloudFoundry
  module Middleware
    RSpec.describe ConcurrencyRateLimiter do
      let(:app) { double(:app, call: [200, {}, 'a body']) }
      let(:logger) { double('logger', info: nil, error: nil) }
      let(:user_guid) { 'user-id-1' }
      let(:user_env) { { 'cf.user_guid' => user_guid, 'PATH_INFO' => '/v3/apps' } }
      let(:blocking_limit) { 2 }
      let(:logging_limit) { nil }
      let(:concurrency_limiter) do
        instance_double(ConcurrencyLimiter, try_increment?: true, decrement: nil, suggested_retry_after: 1,
                                            error_name: 'ConcurrentRequestLimitExceeded',
                                            error_name_ip_based: 'IPBasedConcurrentRequestLimitExceeded')
      end

      let(:middleware) do
        ConcurrencyRateLimiter.new(app, logger: logger, blocking_limit: blocking_limit, logging_limit: logging_limit)
      end

      before do
        allow(ConcurrencyLimiter).to receive(:instance).and_return(concurrency_limiter)
      end

      describe '#call' do
        context 'when under the limit' do
          it 'passes the request through' do
            status, = middleware.call(user_env)
            expect(status).to eq(200)
          end

          it 'decrements after the request completes' do
            middleware.call(user_env)
            expect(concurrency_limiter).to have_received(:decrement).with(user_guid)
          end
        end

        context 'when over the limit' do
          before do
            allow(concurrency_limiter).to receive(:try_increment?).and_return(false)
          end

          it 'returns 429' do
            status, = middleware.call(user_env)
            expect(status).to eq(429)
          end

          it 'does not call the app' do
            middleware.call(user_env)
            expect(app).not_to have_received(:call)
          end

          it 'does not decrement after the blocked request' do
            middleware.call(user_env)
            expect(concurrency_limiter).not_to have_received(:decrement)
          end

          it 'includes Retry-After header as seconds' do
            _, response_headers, = middleware.call(user_env)
            expect(response_headers['Retry-After'].to_i).to be > 0
          end

          context 'when the path is /v3' do
            it 'formats the error in v3 format' do
              _, _, body = middleware.call(user_env)
              json_body = Oj.load(body.first)
              expect(json_body['errors'].first).to include(
                'title' => 'CF-ConcurrentRequestLimitExceeded',
                'code' => 10_021
              )
            end
          end

          context 'when the path is /v2' do
            let(:user_env) { { 'cf.user_guid' => user_guid, 'PATH_INFO' => '/v2/apps' } }

            it 'formats the error in v2 format' do
              _, _, body = middleware.call(user_env)
              json_body = Oj.load(body.first)
              expect(json_body).to include(
                'error_code' => 'CF-ConcurrentRequestLimitExceeded',
                'code' => 10_021
              )
            end
          end
        end

        context 'when an error is raised in the app' do
          before do
            allow(app).to receive(:call).and_raise('an error')
          end

          it 'still decrements' do
            expect { middleware.call(user_env) }.to raise_error('an error')
            expect(concurrency_limiter).to have_received(:decrement).with(user_guid)
          end
        end

        context 'when using an unauthenticated request (IP-based)' do
          let(:ip_env) { { 'PATH_INFO' => '/v3/apps', 'REMOTE_ADDR' => '1.2.3.4', 'HTTP_X_FORWARDED_FOR' => '1.2.3.4' } }
          let(:fake_request) { instance_double(ActionDispatch::Request, fullpath: '/v3/apps', ip: '1.2.3.4', headers: { 'HTTP_X_FORWARDED_FOR' => '1.2.3.4' }) }

          before do
            allow(ActionDispatch::Request).to receive(:new).and_return(fake_request)
          end

          it 'uses IP as the user identifier' do
            middleware.call(ip_env)
            expect(concurrency_limiter).to have_received(:try_increment?).with('1.2.3.4')
          end

          context 'when over the limit' do
            before do
              allow(concurrency_limiter).to receive_messages(try_increment?: false, error_name_ip_based: 'IPBasedConcurrentRequestLimitExceeded')
            end

            it 'uses the IP-based error name' do
              _, _, body = middleware.call(ip_env)
              json_body = Oj.load(body.first)
              expect(json_body['errors'].first['title']).to eq('CF-IPBasedConcurrentRequestLimitExceeded')
            end
          end
        end

        describe 'bypassed requests' do
          context 'internal API' do
            let(:internal_env) { { 'cf.user_guid' => user_guid, 'PATH_INFO' => '/internal/v4/asg_latest_update' } }
            let(:fake_request) { instance_double(ActionDispatch::Request, fullpath: '/internal/v4/asg_latest_update') }

            before { allow(ActionDispatch::Request).to receive(:new).and_return(fake_request) }

            it 'does not rate limit' do
              middleware.call(internal_env)
              expect(concurrency_limiter).not_to have_received(:try_increment?)
            end
          end

          context 'root API paths' do
            %w[/v2/info /v3 / /healthz].each do |path|
              context path do
                let(:root_env) { { 'cf.user_guid' => user_guid, 'PATH_INFO' => path } }
                let(:fake_request) { instance_double(ActionDispatch::Request, fullpath: path) }

                before { allow(ActionDispatch::Request).to receive(:new).and_return(fake_request) }

                it 'does not rate limit' do
                  middleware.call(root_env)
                  expect(concurrency_limiter).not_to have_received(:try_increment?)
                end
              end
            end
          end

          context 'basic auth request' do
            let(:basic_auth_env) do
              user_env.merge('HTTP_AUTHORIZATION' => 'Basic ' + Base64.encode64('user:pass').strip)
            end

            it 'does not rate limit' do
              middleware.call(basic_auth_env)
              expect(concurrency_limiter).not_to have_received(:try_increment?)
            end
          end
        end
      end
    end

    RSpec.describe ConcurrencyLimiter do
      let(:logger) { double('logger', info: nil, error: nil) }
      let(:blocking_limit) { 3 }
      let(:logging_limit) { 2 }
      let(:user_guid) { 'user-id-1' }

      subject(:limiter) { ConcurrencyLimiter.new(logger, blocking_limit: blocking_limit, logging_limit: logging_limit) }

      before do
        limiter.instance_variable_set(:@store, ConcurrentInMemoryStore.new)
      end

      describe '#try_increment?' do
        it 'returns true when under the blocking limit' do
          expect(limiter.try_increment?(user_guid)).to be true
        end

        it 'returns false when over the blocking limit' do
          blocking_limit.times { limiter.try_increment?(user_guid) }
          expect(limiter.try_increment?(user_guid)).to be false
        end

        it 'does not consume a slot for a rejected request (no phantom count)' do
          blocking_limit.times { limiter.try_increment?(user_guid) }
          # repeated rejected attempts must not increment the counter...
          5.times { expect(limiter.try_increment?(user_guid)).to be false }
          # ...so freeing exactly one slot admits exactly one request, then blocks again
          limiter.decrement(user_guid)
          expect(limiter.try_increment?(user_guid)).to be true
          expect(limiter.try_increment?(user_guid)).to be false
        end

        it 'logs a warning when count exceeds logging_limit' do
          logging_limit.times { limiter.try_increment?(user_guid) }
          limiter.try_increment?(user_guid)
          expect(logger).to have_received(:info).with(/Concurrency limit warning/)
        end

        it 'does not log warning when under logging_limit' do
          limiter.try_increment?(user_guid)
          expect(logger).not_to have_received(:info)
        end

        it 'logs rate limit exceeded when blocked' do
          blocking_limit.times { limiter.try_increment?(user_guid) }
          limiter.try_increment?(user_guid)
          expect(logger).to have_received(:info).with(/Concurrent rate limit exceeded/)
        end

        context 'with only logging_limit (no blocking_limit)' do
          subject(:limiter) { ConcurrencyLimiter.new(logger, logging_limit: logging_limit) }

          it 'always returns true' do
            10.times { limiter.try_increment?(user_guid) }
            expect(limiter.try_increment?(user_guid)).to be true
          end

          it 'logs a warning when count exceeds logging_limit but does not block' do
            logging_limit.times { limiter.try_increment?(user_guid) }
            result = limiter.try_increment?(user_guid)
            expect(result).to be true
            expect(logger).to have_received(:info).with(/Concurrency limit warning/)
          end
        end

        context 'with only blocking_limit (no logging_limit)' do
          subject(:limiter) { ConcurrencyLimiter.new(logger, blocking_limit: blocking_limit) }

          it 'returns false when over the blocking limit' do
            blocking_limit.times { limiter.try_increment?(user_guid) }
            expect(limiter.try_increment?(user_guid)).to be false
          end

          it 'does not log any warnings' do
            blocking_limit.times { limiter.try_increment?(user_guid) }
            limiter.try_increment?(user_guid)
            expect(logger).not_to have_received(:info).with(/Concurrency limit warning/)
          end
        end

        context 'with neither blocking_limit nor logging_limit' do
          subject(:limiter) { ConcurrencyLimiter.new(logger) }

          it 'always returns true without hitting the store' do
            store = instance_double(ConcurrentInMemoryStore)
            allow(store).to receive(:try_acquire)
            limiter.instance_variable_set(:@store, store)
            expect(limiter.try_increment?(user_guid)).to be true
            expect(store).not_to have_received(:try_acquire)
          end
        end

        context 'with negative limits (disabled)' do
          subject(:limiter) { ConcurrencyLimiter.new(logger, blocking_limit: -1, logging_limit: -1) }

          it 'always returns true without hitting the store' do
            store = instance_double(ConcurrentInMemoryStore)
            allow(store).to receive(:try_acquire)
            limiter.instance_variable_set(:@store, store)
            expect(limiter.try_increment?(user_guid)).to be true
            expect(store).not_to have_received(:try_acquire)
          end
        end

        context 'when store raises StoreError' do
          before do
            store = instance_double(ConcurrentInMemoryStore)
            allow(store).to receive(:try_acquire).and_raise(StoreError)
            limiter.instance_variable_set(:@store, store)
          end

          it 'fails open and returns true' do
            expect(limiter.try_increment?(user_guid)).to be true
          end
        end
      end

      describe '#decrement' do
        it 'decrements the counter' do
          blocking_limit.times { limiter.try_increment?(user_guid) }
          limiter.decrement(user_guid)
          expect(limiter.try_increment?(user_guid)).to be true
        end

        context 'with neither blocking_limit nor logging_limit' do
          subject(:limiter) { ConcurrencyLimiter.new(logger) }

          it 'does not hit the store' do
            store = instance_double(ConcurrentInMemoryStore)
            allow(store).to receive(:decrement)
            limiter.instance_variable_set(:@store, store)
            limiter.decrement(user_guid)
            expect(store).not_to have_received(:decrement)
          end
        end

        context 'with negative limits (disabled)' do
          subject(:limiter) { ConcurrencyLimiter.new(logger, blocking_limit: -1, logging_limit: -1) }

          it 'does not hit the store' do
            store = instance_double(ConcurrentInMemoryStore)
            allow(store).to receive(:decrement)
            limiter.instance_variable_set(:@store, store)
            limiter.decrement(user_guid)
            expect(store).not_to have_received(:decrement)
          end
        end

        context 'when store raises StoreError' do
          before do
            store = instance_double(ConcurrentInMemoryStore)
            allow(store).to receive(:decrement).and_raise(StoreError)
            limiter.instance_variable_set(:@store, store)
          end

          it 'does not raise' do
            expect { limiter.decrement(user_guid) }.not_to raise_error
          end
        end
      end

      describe '#suggested_retry_after' do
        it 'returns a positive integer' do
          expect(limiter.suggested_retry_after).to be >= 1
        end

        it 'returns a value between 1 and 5' do
          100.times { expect(limiter.suggested_retry_after).to be_between(1, 5) }
        end
      end
    end

    RSpec.describe ConcurrentInMemoryStore do
      let(:store) { ConcurrentInMemoryStore.new }
      let(:logger) { double('logger') }
      let(:key) { 'test-key' }

      describe '#try_acquire' do
        it 'returns 1 for a new key' do
          expect(store.try_acquire(key, 10, logger)).to eq(1)
        end

        it 'increments on each successful acquire' do
          store.try_acquire(key, 10, logger)
          expect(store.try_acquire(key, 10, logger)).to eq(2)
        end

        it 'returns nil without incrementing when at the limit' do
          2.times { store.try_acquire(key, 2, logger) }
          expect(store.try_acquire(key, 2, logger)).to be_nil
          # rejected attempt did not consume a slot: freeing one admits exactly one more
          store.decrement(key, logger)
          expect(store.try_acquire(key, 2, logger)).to eq(2)
        end

        it 'treats a nil limit as unlimited' do
          5.times { store.try_acquire(key, nil, logger) }
          expect(store.try_acquire(key, nil, logger)).to eq(6)
        end
      end

      describe '#decrement' do
        it 'returns 0 for a non-existent key' do
          expect(store.decrement(key, logger)).to eq(0)
        end

        it 'decrements the counter' do
          store.try_acquire(key, 10, logger)
          store.try_acquire(key, 10, logger)
          expect(store.decrement(key, logger)).to eq(1)
        end

        it 'removes the key when count reaches 0' do
          store.try_acquire(key, 10, logger)
          store.decrement(key, logger)
          expect(store.instance_variable_get(:@data)).not_to have_key(key)
        end

        it 'does not go below 0' do
          store.decrement(key, logger)
          expect(store.decrement(key, logger)).to eq(0)
        end
      end
    end

    RSpec.describe ConcurrentRedisStore do
      let(:logger) { double('logger', error: nil) }
      let(:key) { 'test-key' }
      let(:redis) { MockRedis.new }
      let(:store) { ConcurrentRedisStore.new(redis) }

      # MockRedis cannot execute Lua, so simulate ACQUIRE_SCRIPT faithfully against the same
      # mock instance. Real atomicity is exercised in integration against a live Redis.
      before do
        allow(redis).to receive(:eval) do |_script, **opts|
          k = opts[:keys].first
          limit = opts[:argv][0].to_i
          ttl = opts[:argv][1].to_i
          current = redis.get(k).to_i
          if limit >= 0 && current >= limit
            -1
          else
            count = redis.incr(k)
            redis.expire(k, ttl) if ttl > 0
            count
          end
        end
      end

      describe '#try_acquire' do
        it 'returns 1 for a new key' do
          expect(store.try_acquire(key, 10, logger)).to eq(1)
        end

        it 'increments on each successful acquire' do
          store.try_acquire(key, 10, logger)
          expect(store.try_acquire(key, 10, logger)).to eq(2)
        end

        it 'returns nil without incrementing when at the limit' do
          2.times { store.try_acquire(key, 2, logger) }
          expect(store.try_acquire(key, 2, logger)).to be_nil
          expect(redis.get(key).to_i).to eq(2)
        end

        it 'treats a nil limit as unlimited' do
          5.times { store.try_acquire(key, nil, logger) }
          expect(store.try_acquire(key, nil, logger)).to eq(6)
        end

        context 'with TTL configured' do
          let(:store) { ConcurrentRedisStore.new(redis, counter_ttl_seconds: 60) }

          it 'sets TTL when acquiring' do
            allow(redis).to receive(:expire).and_call_original
            store.try_acquire(key, 10, logger)
            expect(redis).to have_received(:expire).with(key, 60)
          end
        end

        context 'when Redis raises an error' do
          before { allow(redis).to receive(:eval).and_raise(Redis::ConnectionError) }

          it 'logs the error and raises StoreError' do
            expect { store.try_acquire(key, 10, logger) }.to raise_error(StoreError)
            expect(logger).to have_received(:error).with(/Redis error/)
          end
        end
      end

      describe '#decrement' do
        it 'decrements the counter' do
          store.try_acquire(key, 10, logger)
          store.try_acquire(key, 10, logger)
          expect(store.decrement(key, logger)).to eq(1)
        end

        it 'does not go below 0 when key does not exist' do
          store.decrement(key, logger)
          expect(store.try_acquire(key, 10, logger)).to eq(1)
        end

        it 'returns 0 when key expired mid-flight' do
          store.try_acquire(key, 10, logger)
          store.instance_variable_get(:@redis).del(key) # simulate TTL expiry
          expect(store.decrement(key, logger)).to eq(0)
        end

        context 'when Redis raises an error' do
          before { allow(store.instance_variable_get(:@redis)).to receive(:decr).and_raise(Redis::ConnectionError) }

          it 'logs the error and raises StoreError' do
            expect { store.decrement(key, logger) }.to raise_error(StoreError)
            expect(logger).to have_received(:error).with(/Redis error/)
          end
        end
      end
    end
  end
end
