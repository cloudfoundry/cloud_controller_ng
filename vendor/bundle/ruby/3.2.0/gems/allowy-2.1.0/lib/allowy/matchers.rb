module Allowy
  module Matchers

    class AbleToMatcher
      def initialize(action, subject=nil, *params)
        @action, @subject, @params = action, subject, params
      end

      def say msg
        "#{msg} #{@action} #{@subject.inspect}"
      end

      def matches?(access_control)
        access_control.can?(@action, @subject, *@params)
      end

      def description
        say "be able to"
      end

      def failure_message
        say "expected to be able to"
      end

      def negative_failure_message
        say "expected NOT to be able to"
      end

      alias_method :failure_message_when_negated, :negative_failure_message
    end

    def be_able_to(*args)
      AbleToMatcher.new(*args)
    end
  end
end

module RSpec::Matchers
  include Allowy::Matchers
end
