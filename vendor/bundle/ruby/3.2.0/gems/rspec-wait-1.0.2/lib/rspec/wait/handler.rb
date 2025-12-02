# frozen_string_literal: true

module RSpec
  module Wait
    # The RSpec::Wait::Handler module is common functionality shared between
    # the RSpec::Wait::PositiveHandler and RSpec::Wait::NegativeHandler classes
    # defined below. The module overrides RSpec's handle_matcher method,
    # allowing a block target to be repeatedly evaluated until the underlying
    # matcher passes or the configured timeout elapses.
    module Handler
      def handle_matcher(target, initial_matcher, message, &block)
        start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)

        begin
          matcher = RSpec.configuration.clone_wait_matcher ? initial_matcher.clone : initial_matcher

          if matcher.respond_to?(:supports_block_expectations?) && matcher.supports_block_expectations?
            super(target, matcher, message, &block)
          else
            super(target.call, matcher, message, &block)
          end
        rescue RSpec::Expectations::ExpectationNotMetError
          raise if RSpec.world.wants_to_quit

          elapsed_time = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time
          raise if elapsed_time > RSpec.configuration.wait_timeout

          sleep RSpec.configuration.wait_delay
          retry
        end
      end
    end

    # From: https://github.com/rspec/rspec-expectations/blob/v3.4.0/lib/rspec/expectations/handler.rb#L46-L65
    class PositiveHandler < RSpec::Expectations::PositiveExpectationHandler
      extend Handler
    end

    # From: https://github.com/rspec/rspec-expectations/blob/v3.4.0/lib/rspec/expectations/handler.rb#L68-L95
    class NegativeHandler < RSpec::Expectations::NegativeExpectationHandler
      extend Handler
    end
  end
end
