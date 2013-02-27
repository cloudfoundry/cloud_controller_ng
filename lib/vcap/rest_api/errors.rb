# Copyright (c) 2009-2012 VMware, Inc.

module VCAP::RestAPI
  module Errors
    HTTP = VCAP::RestAPI::HTTP

    class Error < StandardError
      attr_reader :response_code
      attr_reader :error_code

      # Initialize a rest api error (not for direct use by callers)
      #
      # @param [Integer] response_code HTTP response code
      #
      # @param [Integer] error_code VCAP specific error code
      #
      # @param [String] format sprintf format string used to format the
      # error message
      #
      # @param [Array] args arguments to the sprintf format string
      #
      # @return [RestAPI::Error] error instance
      def initialize(response_code, error_code, format, *args)
        @response_code = response_code
        @error_code = error_code
        msg = sprintf(format, *args)
        super(msg)
      end
    end

    module ClassMethods
      # Define a new rest api error class.
      #
      # @param [String] class_name Name of the class.
      #
      # @param [Integer] response_code HTTP response code
      #
      # @param [Integer] error_code VCAP specific error code.
      #
      # @param [String] format sprintf format string used to format the
      # error message
      def define_error(class_name, response_code, error_code, format)
        klass = Class.new Error do
          define_method :initialize do |*args|
            super(response_code, error_code, format, *args)
          end
        end

        const_set(class_name, klass)
      end

      def define_base_errors
        define_error("NotFound", HTTP::NOT_FOUND, 10000, "Unknown request")

        define_error("ServerError", HTTP::INTERNAL_SERVER_ERROR,
                     10001, "Server error")

        define_error("NotAuthenticated", HTTP::UNAUTHORIZED,
                     10002, "Authentication error")

        define_error("NotAuthorized", HTTP::FORBIDDEN, 10003,
                     "You are not authorized to perform the requested action")

        define_error("InvalidRequest", HTTP::BAD_REQUEST, 10004,
                     "The request is invalid")

        define_error("BadQueryParameter", HTTP::BAD_REQUEST, 10005,
                     "The query parameter is invalid: %s")
      end

    end

    def self.included(base)
      base.extend(ClassMethods)
    end

    extend(ClassMethods)
    define_base_errors

  end
end
