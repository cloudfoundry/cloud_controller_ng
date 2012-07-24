# Copyright (c) 2009-2012 VMware, Inc.

require "vcap/rest_api"
require "sinatra/consumes"
require "sinatra/reloader"
require "securerandom"
require "steno"

module Sinatra
  module VCAP
    module Helpers
      # Generate an http body from a vcap rest api style exception
      #
      # @param [VCAP::RestAPI::Error] The exception used to generate
      # an http body.
      def body_from_vcap_exception(exception)
        error_payload                = {}
        error_payload["code"]        = exception.error_code
        error_payload["description"] = exception.message
        body Yajl::Encoder.encode(error_payload).concat("\n")
      end

      # Test if an exception matches the vcap api style exception.
      #
      # @param [Exception] The exception to check.
      #
      # @return [Bool] True if the provided exception can be formatted
      # like a vcap rest api style exception.
      def is_vcap_error?(exception)
        exception.respond_to?(:error_code) && exception.respond_to?(:message)
      end
    end

    # Called when the caller registers the sinatra extension.  Sets up
    # the standard sinatra environment for vcap.
    def self.registered(app)
      app.helpers Sinatra::Consumes
      app.helpers VCAP::Helpers

      app.not_found do
        body_from_vcap_exception(::VCAP::RestAPI::Errors::NotFound.new)
      end

      app.error do
        exception = request.env["sinatra.error"]
        if is_vcap_error?(exception)
          logger.debug("Request failed with response code: " +
                       "#{exception.response_code} error code: " +
                       "#{exception.error_code} error: #{exception.message}")
          status(exception.response_code)
          body_from_vcap_exception(exception)
        else
          msg = ["#{exception.class} - #{exception.message}"]
          msg[0] = msg[0] + ":"
          msg.concat(exception.backtrace)
          logger.error(msg.join("\n"))
          body_from_vcap_exception(::VCAP::RestAPI::Errors::ServerError.new)
          status(500)
        end
      end
    end

    # A user of the VCAP sinatra extension must call vcap_configure
    # in order to setup error handling correctly.  Unfortunately,
    # we are not able to do this from inside self.registered as sinatra
    # doesn't honor the settings we make there.
    #
    # @option opts [String] :logger_name Name of the Steno logger to use.
    # Defaults to vcap.rest_api
    #
    # @option opts [String] :reload_path If specified and the app is running in
    # :development mode, sinatra will reload all files under the provided path
    # whenever they change.
    def vcap_configure(opts = {})
      # we can't just do this in registered sinatra seems to reset
      # our configuration after register
      configure do
        set(:show_exceptions, false)
        set(:raise_errors, false)
        set(:dump_errors, false)
      end

      configure :development do
        register Sinatra::Reloader
        if opts[:reload_path]
          Dir["#{opts[:reload_path]}/**/*.rb"].each do |file|
            also_reload file
          end
        end
      end

      before do
        # TODO: wrap the logger with a sesion logger like we
        # do in caldecott
        logger_name = opts[:logger_name] || "vcap.api"
        env["rack.logger"] = Steno.logger(logger_name)
        @request_guid = SecureRandom.uuid
        Steno.config.context.data["request_guid"] = @request_guid
      end

      after do
        headers["X-VCAP-Request-ID"] = @request_guid
        nil
      end
    end
  end

  register VCAP
end
