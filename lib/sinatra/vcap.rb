# Copyright (c) 2009-2012 VMware, Inc.

require "vcap/component"
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

      def varz
        ::VCAP::Component.varz[:vcap_sinatra]
      end
    end

    # Called when the caller registers the sinatra extension.  Sets up
    # the standard sinatra environment for vcap.
    def self.registered(app)
      init_varz

      app.helpers Sinatra::Consumes
      app.helpers VCAP::Helpers

      app.not_found do
        # sinatra wants to drive us through the not_found block for *every*
        # 404, with no way of disabling it. We want the logic in this block
        # for access to non-existent urls, but not for 404s that we return
        # from our logic. This is a check to see if we already did a 404 below.
        # We don't really have a class to attach a member variable to, so we have to
        # use the env to flag this.
        unless request.env["vcap_exception_body_set"]
          body_from_vcap_exception(::VCAP::RestAPI::Errors::NotFound.new)
        end
      end

      app.error do
        exception = request.env["sinatra.error"]
        if is_vcap_error?(exception)
          logger.debug("Request failed with response code: " +
                       "#{exception.response_code} error code: " +
                       "#{exception.error_code} error: #{exception.message}")
          status(exception.response_code)
          request.env["vcap_exception_body_set"] = true
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
        ::VCAP::Component.varz.synchronize do
          varz[:requests][:outstanding] += 1
        end
        logger_name = opts[:logger_name] || "vcap.api"
        env["rack.logger"] = Steno.logger(logger_name)
        @request_guid = SecureRandom.uuid
        Thread.current[:vcap_request_id] = @request_guid
        Steno.config.context.data["request_guid"] = @request_guid
      end

      after do
        ::VCAP::Component.varz.synchronize do
          varz[:requests][:outstanding] -= 1
          varz[:requests][:completed] += 1
          varz[:http_status][response.status] += 1
        end
        headers["X-VCAP-Request-ID"] = @request_guid
        Thread.current[:vcap_request_id] = nil
        Steno.config.context.data.delete("request_guid")
        nil
      end
    end

    private

    def self.init_varz
      ::VCAP::Component.varz.threadsafe!

      requests = { :outstanding => 0, :completed => 0 }
      http_status = {}
      [(100..101), (200..206), (300..307), (400..417), (500..505)].each do |r|
        r.each { |c| http_status[c] = 0 }
      end
      vcap_sinatra = { :requests => requests, :http_status => http_status }
      ::VCAP::Component.varz.synchronize do
        ::VCAP::Component.varz[:vcap_sinatra] ||= vcap_sinatra
      end
    end
  end

  register VCAP
end
