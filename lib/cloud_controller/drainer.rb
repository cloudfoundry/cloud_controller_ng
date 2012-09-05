# Copyright (c) 2009-2012 VMware, Inc.

module VCAP::CloudController
  class DrainerError < StandardError
  end

  class Drainer
    module State
      READY    = 0 # Drainer is ready to drain.
      DRAINING = 1 # Draining now.
      DONE     = 3 # Draining complete.
    end

    class << self

      def setup(poll_time = 1)
        check_no_state

        @poll_time = poll_time
        @inflight_requests = 0
        @before_drain_callbacks = []
        @after_drain_callbacks = []

        @lock = Mutex.new
        @state = State::READY
      end

      def requests
        check_lock
        requests = nil

        @lock.synchronize do
          check_state(State::READY)
          requests = @inflight_requests
        end

        requests
      end

      def increment_requests
        check_lock

        @lock.synchronize do
          check_state(State::READY)
          @inflight_requests += 1
        end
      end

      def decrement_requests
        check_lock

        @lock.synchronize do
          check_state(State::READY)
          @inflight_requests -= 1
        end
      end

      def drain
        check_lock

        @lock.synchronize do
          check_state(State::READY)
          @state = State::DRAINING
          @before_drain_callbacks.each { |callback| callback.call }

          loop do
            break if @inflight_requests <= 0
            sleep @poll_time
          end

          @after_drain_callbacks.each { |callback| callback.call }
          @state = State::DONE
        end
      end

      def queue_before_drain(&block)
        check_lock

        @lock.synchronize do
          check_state(State::READY)
          @before_drain_callbacks << block
        end
      end

      def queue_after_drain(&block)
        check_lock

        @lock.synchronize do
          check_state(State::READY)
          @after_drain_callbacks << block
        end
      end

      private

      def check_no_state
        raise DrainerError.new("Drainer has already been setup.") if @state
      end

      def check_state(state)
        raise DrainerError.new("Invalid state!") unless @state == state
      end

      def check_lock
        raise DrainerError.new("Drainer has not been setup yet.") unless @lock
      end
    end
  end
end
