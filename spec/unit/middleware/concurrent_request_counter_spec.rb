require 'spec_helper'

module CloudFoundry
  module Middleware
    RSpec.describe ConcurrentRequestCounter do
      let(:logger) { double('logger', info: nil, error: nil) }
      let(:blocking_limit) { 3 }
      let(:logging_limit) { 2 }
      let(:user_guid) { 'user-id-1' }

      subject(:counter) do
        ConcurrentRequestCounter.new('test', blocking_limit: blocking_limit, logging_limit: logging_limit)
      end

      before do
        counter.instance_variable_set(:@store, ConcurrentRequestCounter::InMemoryStore.new)
      end

      describe '#try_increment?' do
        it 'returns true when under the blocking limit' do
          expect(counter.try_increment?(user_guid, logger)).to be true
        end

        it 'returns false when over the blocking limit' do
          blocking_limit.times { counter.try_increment?(user_guid, logger) }
          expect(counter.try_increment?(user_guid, logger)).to be false
        end

        it 'does not consume a slot for a rejected request (no phantom count)' do
          blocking_limit.times { counter.try_increment?(user_guid, logger) }
          5.times { expect(counter.try_increment?(user_guid, logger)).to be false }
          counter.decrement(user_guid, logger)
          expect(counter.try_increment?(user_guid, logger)).to be true
          expect(counter.try_increment?(user_guid, logger)).to be false
        end

        context 'with only logging_limit (no blocking_limit)' do
          subject(:counter) { ConcurrentRequestCounter.new('test', logging_limit: logging_limit) }

          before do
            counter.instance_variable_set(:@store, ConcurrentRequestCounter::InMemoryStore.new)
          end

          it 'always returns true' do
            10.times { counter.try_increment?(user_guid, logger) }
            expect(counter.try_increment?(user_guid, logger)).to be true
          end

          it 'logs a warning when count exceeds logging_limit but does not block' do
            logging_limit.times { counter.try_increment?(user_guid, logger) }
            result = counter.try_increment?(user_guid, logger)
            expect(result).to be true
            expect(logger).to have_received(:info).with(/Concurrency limit warning/)
          end
        end

        context 'with only blocking_limit (no logging_limit)' do
          subject(:counter) { ConcurrentRequestCounter.new('test', blocking_limit: blocking_limit) }

          before do
            counter.instance_variable_set(:@store, ConcurrentRequestCounter::InMemoryStore.new)
          end

          it 'returns false when over the blocking limit' do
            blocking_limit.times { counter.try_increment?(user_guid, logger) }
            expect(counter.try_increment?(user_guid, logger)).to be false
          end

          it 'does not log any warnings' do
            blocking_limit.times { counter.try_increment?(user_guid, logger) }
            counter.try_increment?(user_guid, logger)
            expect(logger).not_to have_received(:info).with(/Concurrency limit warning/)
          end
        end

        context 'with neither blocking_limit nor logging_limit' do
          it 'always returns true without hitting the store' do
            counter = ConcurrentRequestCounter.new('test')
            store = instance_double(ConcurrentRequestCounter::InMemoryStore)
            allow(store).to receive(:try_increment)
            counter.instance_variable_set(:@store, store)
            expect(counter.try_increment?(user_guid, logger)).to be true
            expect(store).not_to have_received(:try_increment)
          end
        end

        context 'with negative limits (disabled)' do
          it 'always returns true without hitting the store' do
            counter = ConcurrentRequestCounter.new('test', blocking_limit: -1, logging_limit: -1)
            store = instance_double(ConcurrentRequestCounter::InMemoryStore)
            allow(store).to receive(:try_increment)
            counter.instance_variable_set(:@store, store)
            expect(counter.try_increment?(user_guid, logger)).to be true
            expect(store).not_to have_received(:try_increment)
          end
        end

        context 'when store raises StoreError' do
          before do
            store = instance_double(ConcurrentRequestCounter::InMemoryStore)
            allow(store).to receive(:try_increment).and_raise(StoreError)
            counter.instance_variable_set(:@store, store)
          end

          it 'fails open and returns true' do
            expect(counter.try_increment?(user_guid, logger)).to be true
          end
        end
      end

      describe '#decrement' do
        it 'decrements the counter' do
          blocking_limit.times { counter.try_increment?(user_guid, logger) }
          counter.decrement(user_guid, logger)
          expect(counter.try_increment?(user_guid, logger)).to be true
        end

        context 'with neither blocking_limit nor logging_limit' do
          it 'does not hit the store' do
            counter = ConcurrentRequestCounter.new('test')
            store = instance_double(ConcurrentRequestCounter::InMemoryStore)
            allow(store).to receive(:decrement)
            counter.instance_variable_set(:@store, store)
            counter.decrement(user_guid, logger)
            expect(store).not_to have_received(:decrement)
          end
        end

        context 'with negative limits (disabled)' do
          it 'does not hit the store' do
            counter = ConcurrentRequestCounter.new('test', blocking_limit: -1, logging_limit: -1)
            store = instance_double(ConcurrentRequestCounter::InMemoryStore)
            allow(store).to receive(:decrement)
            counter.instance_variable_set(:@store, store)
            counter.decrement(user_guid, logger)
            expect(store).not_to have_received(:decrement)
          end
        end

        context 'when store raises StoreError' do
          before do
            store = instance_double(ConcurrentRequestCounter::InMemoryStore)
            allow(store).to receive(:decrement).and_raise(StoreError)
            counter.instance_variable_set(:@store, store)
          end

          it 'does not raise' do
            expect { counter.decrement(user_guid, logger) }.not_to raise_error
          end
        end
      end
    end

    RSpec.describe ConcurrentRequestCounter::InMemoryStore do
      let(:store) { ConcurrentRequestCounter::InMemoryStore.new }
      let(:logger) { double('logger') }
      let(:key) { 'test-key' }

      describe '#try_increment' do
        it 'returns 1 for a new key' do
          expect(store.try_increment(key, 10, logger)).to eq(1)
        end

        it 'increments on each successful call' do
          store.try_increment(key, 10, logger)
          expect(store.try_increment(key, 10, logger)).to eq(2)
        end

        it 'returns nil without incrementing when at the limit' do
          2.times { store.try_increment(key, 2, logger) }
          expect(store.try_increment(key, 2, logger)).to be_nil
          store.decrement(key, logger)
          expect(store.try_increment(key, 2, logger)).to eq(2)
        end
      end

      describe '#try_log_increment' do
        it 'always increments with no cap' do
          5.times { store.try_log_increment(key, logger) }
          expect(store.try_log_increment(key, logger)).to eq(6)
        end
      end

      describe '#decrement' do
        it 'returns 0 for a non-existent key' do
          expect(store.decrement(key, logger)).to eq(0)
        end

        it 'decrements the counter' do
          store.try_increment(key, 10, logger)
          store.try_increment(key, 10, logger)
          expect(store.decrement(key, logger)).to eq(1)
        end

        it 'removes the key when count reaches 0' do
          store.try_increment(key, 10, logger)
          store.decrement(key, logger)
          expect(store.instance_variable_get(:@data)).not_to have_key(key)
        end

        it 'does not go below 0' do
          store.decrement(key, logger)
          expect(store.decrement(key, logger)).to eq(0)
        end
      end
    end

    RSpec.describe ConcurrentRequestCounter::RedisStore do
      let(:logger) { double('logger', error: nil) }
      let(:key) { 'test-key' }
      let(:redis) { MockRedis.new }
      let(:store) do
        s = ConcurrentRequestCounter::RedisStore.new('/tmp/test.sock', 1, nil)
        s.instance_variable_set(:@redis, redis)
        s
      end

      before do
        allow(redis).to receive(:evalsha) do |sha, **opts|
          k = opts[:keys].first
          if sha == ConcurrentRequestCounter::RedisStore::INCREMENT_SHA
            limit = opts[:argv][0].to_i
            ttl   = opts[:argv][1].to_i
            current = redis.get(k).to_i
            if current >= limit
              -1
            else
              count = redis.incr(k)
              redis.expire(k, ttl) if count == 1 && ttl > 0
              count
            end
          elsif sha == ConcurrentRequestCounter::RedisStore::LOG_INCREMENT_SHA
            ttl   = opts[:argv][0].to_i
            count = redis.incr(k)
            redis.expire(k, ttl) if count == 1 && ttl > 0
            count
          end
        end
      end

      describe '#try_increment' do
        it 'returns 1 for a new key' do
          expect(store.try_increment(key, 10, logger)).to eq(1)
        end

        it 'increments on each successful call' do
          store.try_increment(key, 10, logger)
          expect(store.try_increment(key, 10, logger)).to eq(2)
        end

        it 'returns nil without incrementing when at the limit' do
          2.times { store.try_increment(key, 2, logger) }
          expect(store.try_increment(key, 2, logger)).to be_nil
          expect(redis.get(key).to_i).to eq(2)
        end

        context 'with TTL configured' do
          let(:store) do
            s = ConcurrentRequestCounter::RedisStore.new('/tmp/test.sock', 1, 60)
            s.instance_variable_set(:@redis, redis)
            s
          end

          it 'sets TTL only on the first increment' do
            allow(redis).to receive(:expire).and_call_original
            store.try_increment(key, 10, logger)
            store.try_increment(key, 10, logger)
            expect(redis).to have_received(:expire).with(key, 60).once
          end
        end

        context 'when NOSCRIPT is raised' do
          before do
            allow(redis).to receive(:evalsha).and_raise(Redis::CommandError.new('NOSCRIPT No matching script'))
            # allow(redis).to receive(:eval) is unreliable because Kernel#eval shadows the stub;
            # define_singleton_method directly on the instance avoids that.
            redis.define_singleton_method(:eval) { |*_args, **_kwargs| 1 }
          end

          it 'falls back to eval and returns count' do
            expect(store.try_increment(key, 10, logger)).to eq(1)
          end
        end

        context 'when Redis raises an error' do
          before { allow(redis).to receive(:evalsha).and_raise(Redis::ConnectionError) }

          it 'logs the error and raises StoreError' do
            expect { store.try_increment(key, 10, logger) }.to raise_error(StoreError)
            expect(logger).to have_received(:error).with(/Redis error/)
          end
        end
      end

      describe '#try_log_increment' do
        it 'always increments with no cap' do
          5.times { store.try_log_increment(key, logger) }
          expect(store.try_log_increment(key, logger)).to eq(6)
        end

        context 'when Redis raises an error' do
          before { allow(redis).to receive(:evalsha).and_raise(Redis::ConnectionError) }

          it 'logs the error and raises StoreError' do
            expect { store.try_log_increment(key, logger) }.to raise_error(StoreError)
            expect(logger).to have_received(:error).with(/Redis error/)
          end
        end
      end

      describe '#decrement' do
        it 'decrements the counter' do
          store.try_increment(key, 10, logger)
          store.try_increment(key, 10, logger)
          expect(store.decrement(key, logger)).to eq(1)
        end

        it 'does not go below 0 when key does not exist' do
          store.decrement(key, logger)
          expect(store.try_increment(key, 10, logger)).to eq(1)
        end

        it 'returns 0 when key expired mid-flight' do
          store.try_increment(key, 10, logger)
          store.instance_variable_get(:@redis).del(key)
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
