require "vcap/rest_api/http_constants"

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
        formatted_args = args.map do |arg|
          (arg.is_a? Array) ? arg.map(&:to_s).join(', ') : arg.to_s
        end
        msg = sprintf(format, *formatted_args)
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
    end

    def self.included(base)
      base.extend(ClassMethods)
    end
  end
end

