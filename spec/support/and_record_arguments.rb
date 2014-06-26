require 'rspec/mocks'

module RSpec
  module Mocks
    class MessageExpectation
      def and_record_arguments
        arg_recorder = ArgumentRecorder.new
        self.argument_list_matcher = arg_recorder
        arg_recorder.arguments
      end
    end

    class ArgumentRecorder < ArgumentListMatcher
      attr_reader :arguments
      def initialize
        @arguments = []
      end

      def args_match?(*args)
        @arguments.push args
      end
    end
  end
end
