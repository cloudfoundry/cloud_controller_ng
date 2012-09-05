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

      def setup(drain_timeout = 5)
        check_no_state

        @inflight_requests = 0
        @drain_timeout = drain_timeout
        @before_drain_callbacks = []
        @after_drain_callbacks = []

        @state = State::READY
        @lock = Mutex.new
        @trigger = ConditionVariable.new
      end

      def ready?
        return true if @state == State::READY && @lock && @trigger
        false
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
        check_trigger

        @lock.synchronize do
          if @inflight_requests == 0
            raise DrainerError.new("Invalid decrement operation.")
          end
          check_state(State::READY, State::DRAINING)
          @inflight_requests -= 1
          @trigger.signal if @inflight_requests == 0
        end
      end

      def drain
        check_lock
        check_trigger

        @lock.synchronize do
          check_state(State::READY)
          @state = State::DRAINING
          @before_drain_callbacks.each { |callback| callback.call }

          @trigger.wait(@mutex, @drain_timeout)  if @inflight_requests > 0

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

      def check_state(*states)
        raise DrainerError.new("Invalid state.") unless states.include?(@state)
      end

      def check_trigger
        unless @trigger
          raise DrainerError.new("Drainer has not been setup yet.")
        end
      end

      def check_lock
        raise DrainerError.new("Drainer has not been setup yet.") unless @lock
      end
    end
  end
end
