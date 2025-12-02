# -*- encoding: utf-8 -*-

module Aliyun
  module Common

    ##
    # Base exception class
    #
    class Exception < RuntimeError
      attr_reader :message

      def initialize(message)
        @message = message
      end
    end

  end # Common
end # Aliyun
