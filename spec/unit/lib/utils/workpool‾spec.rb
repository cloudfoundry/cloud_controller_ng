require 'utils/workpool'

RSpec.describe WorkPool do
  describe '#drain' do
    it 'runs blocks passed in' do
      wp = WorkPool.new(1)
      ran = false
      wp.submit do
        ran = true
      end
      wp.drain
      expect(ran).to be_truthy
    end

    it 'propagates arguments passed in to the inner block' do
      wp = WorkPool.new(1)
      args = []
      wp.submit(1, 2, 3) do |a, b, c|
        args = [a, b, c]
      end
      wp.drain
      expect(args).to eq([1, 2, 3])
    end

    it 'parallelizes up to "size" threads' do
      wp = WorkPool.new(5)

      require 'benchmark'
      time = Benchmark.realtime do
        10.times do
          wp.submit { sleep 0.1 }
        end

        wp.drain
      end

      expect(time).to be_within(0.05).of(0.2)
    end

    it 'finishes running work before draining' do
      wp = WorkPool.new(1)
      ran = false
      wp.submit do
        sleep 0.1
        ran = true
      end
      expect(ran).to be_falsey
      wp.drain
      expect(ran).to be_truthy
    end

    context 'when a queued block raises an exception' do
      context 'when store_exceptions is true' do
        it 'exposes the exception after draining' do
          wp = WorkPool.new(1, store_exceptions: true)
          exception = RuntimeError.new('Boom')
          wp.submit do
            raise exception
          end
          wp.drain

          expect(wp.exceptions).to contain_exactly(exception)
        end

        it 'processes other work in the queue' do
          ran = false
          wp = WorkPool.new(1, store_exceptions: true)
          wp.submit do
            raise 'Boom'
          end
          wp.submit do
            ran = true
          end

          wp.drain
          expect(ran).to be(true)
        end

        it 'accumulates all exceptions raised' do
          wp = WorkPool.new(1, store_exceptions: true)

          3.times do
            wp.submit do
              raise 'Boom'
            end
          end

          wp.drain
          expect(wp.exceptions.length).to be(3)
        end
      end

      context 'when store_exceptions is false' do
        it 'processes other work in the queue' do
          ran = false
          wp = WorkPool.new(1)
          wp.submit do
            raise 'Boom'
          end
          wp.submit do
            ran = true
          end

          wp.drain
          expect(ran).to be(true)
        end

        it 'does NOT accumulate exceptions' do
          wp = WorkPool.new(1)

          3.times do
            wp.submit do
              raise 'Boom'
            end
          end

          wp.drain
          expect(wp.exceptions.length).to be(0)
        end
      end
    end
  end

  describe '#replenish' do
    context 'when there are dead threads in the pool' do
      it 'replaces the dead threads with new ones' do
        thread_count = 2
        wp = WorkPool.new(thread_count)
        wp.submit do
          1 + 1
        end
        wp.drain
        expect(wp.threads.count).to eq(thread_count)
        expect(wp.threads.any?(&:alive?)).to eq false
        wp.replenish

        expect(wp.threads.count).to eq(thread_count)
        expect(wp.threads.all?(&:alive?)).to eq(true)

        ran_this_many_times = 0
        thread_count.times do
          wp.submit do
            ran_this_many_times += 1
          end
        end

        wp.drain
        expect(ran_this_many_times).to eq(thread_count)
      end
    end

    context 'when all of the threads in the pool are healthy' do
      it 'does not modify the healthy threads' do
        thread_count = 2
        wp = WorkPool.new(thread_count)
        wp.submit do
          1 + 1
        end
        original_threads = wp.threads.dup
        expect(wp.threads.count).to eq(thread_count)
        expect(wp.threads.any?(&:alive?)).to eq true
        wp.replenish

        expect(wp.threads.count).to eq(thread_count)
        expect(wp.threads.all?(&:alive?)).to eq(true)

        expect(wp.threads).to eq(original_threads)
      end
    end
  end
end
