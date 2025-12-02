# frozen_string_literal: true

module RSpec
  module Wait
    # The RSpec::Wait::Proxy class is capable of creating a small container
    # object for RSpec::Wait options, returned by the top-level wait method,
    # which allows chaining wait and for methods for more expectations that
    # read more naturally, like:
    #
    #   wait(3.seconds).for { this }.to eq(that)
    #
    class Proxy
      def initialize(**options)
        @options = options
      end

      def for(*args, &block)
        raise ArgumentError, "The `wait.for` method only accepts a block." if args.any?
        raise ArgumentError, "The `wait.for` method requires a block." unless block

        Target.new(block, @options)
      end
    end
  end
end
