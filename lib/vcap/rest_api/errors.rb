# Copyright (c) 2009-2012 VMware, Inc.

module VCAP
  module RestAPI
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
    def self.define_error(class_name, response_code, error_code, format)
      klass = Class.new Error do
        define_method :initialize do |*args|
          super(response_code, error_code, format, *args)
        end
      end

      VCAP::RestAPI.const_set(class_name, klass)
    end

    define_error("NotFound", HTTP::NOT_FOUND, 10000, "Unknown request")

    define_error("ServerError", HTTP::INTERNAL_SERVER_ERROR,
                 10001, "Server error")

    define_error("NotAuthenticated", HTTP::UNAUTHORIZED,
                 10002, "Authentication error")

    define_error("NotAuthorized", HTTP::FORBIDDEN, 10003,
                 "You are not authorized to perform the requested action")

    define_error("InvalidRequest", HTTP::BAD_REQUEST, 10004,
                 "The request is invalid")
  end
end
