# frozen_string_literal: true

module RSpec
  module Wait
    # The RSpec::Wait::Target class inherits from RSpec's internal
    # RSpec::Expectations::ExpectationTarget class and allows the inclusion of
    # RSpec::Wait options via RSpec::Wait::Proxy.
    class Target < RSpec::Expectations::ExpectationTarget
      # From: https://github.com/rspec/rspec-expectations/blob/v3.4.0/lib/rspec/expectations/expectation_target.rb#L25-L27
      def initialize(block, options = {})
        @wait_options = options
        super(block)
      end

      # From: https://github.com/rspec/rspec-expectations/blob/v3.4.0/lib/rspec/expectations/expectation_target.rb#L52-L55
      def to(matcher = nil, message = nil, &block)
        prevent_operator_matchers(:to) unless matcher

        with_wait do
          PositiveHandler.handle_matcher(@target, matcher, message, &block)
        end
      end

      # From: https://github.com/rspec/rspec-expectations/blob/v3.4.0/lib/rspec/expectations/expectation_target.rb#L65-L68
      def not_to(matcher = nil, message = nil, &block)
        prevent_operator_matchers(:not_to) unless matcher

        with_wait do
          NegativeHandler.handle_matcher(@target, matcher, message, &block)
        end
      end

      alias to_not not_to

      private

      def with_wait(&block)
        Wait.with_wait(**@wait_options, &block)
      end
    end
  end
end
