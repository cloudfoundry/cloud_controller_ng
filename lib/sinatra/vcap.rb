require 'vcap/component'
require 'vcap/ring_buffer'
require 'vcap/rest_api'
require 'vcap/request'
require 'presenters/error_presenter'
require 'sinatra/reloader'
require 'securerandom'
require 'steno'

module Sinatra
  module VCAP
    module Helpers
      def varz
        ::VCAP::Component.varz[:vcap_sinatra]
      end

      def in_test_mode?
        ENV['CC_TEST']
      end
    end

    # Called when the caller registers the sinatra extension.  Sets up
    # the standard sinatra environment for vcap.
    def self.registered(app)
      init_varz

      app.helpers VCAP::Helpers

      app.not_found do
        # sinatra wants to drive us through the not_found block for *every*
        # 404, with no way of disabling it. We want the logic in this block
        # for access to non-existent urls, but not for 404s that we return
        # from our logic. This is a check to see if we already did a 404 below.
        # We don't really have a class to attach a member variable to, so we have to
        # use the env to flag this.
        unless request.env['vcap_exception_body_set']
          error = ::VCAP::Errors::ApiError.new_from_details("NotFound")
          presenter = ErrorPresenter.new(error, in_test_mode?)

          body Yajl::Encoder.encode(presenter.error_hash)
        end
      end

      app.error do
        error = request.env['sinatra.error']
        presenter = ErrorPresenter.new(error, in_test_mode?)

        status(presenter.response_code)

        if presenter.client_error?
          logger.info(presenter.log_message)
        else
          logger.error(presenter.log_message)
        end

        payload = Yajl::Encoder.encode(presenter.error_hash)

        ::VCAP::Component.varz.synchronize do
          varz[:recent_errors] << payload
        end

        request.env['vcap_exception_body_set'] = true

        body payload.concat("\n")
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
        logger_name = opts[:logger_name] || 'vcap.api'
        env['rack.logger'] = Steno.logger(logger_name)

        @request_guid = env['HTTP_X_VCAP_REQUEST_ID']
        @request_guid ||= env['HTTP_X_REQUEST_ID']

        # we append a new guid to the request because we have no idea if the
        # caller is really going to be giving us a unique guid, i.e. they might
        # generate the guid and then turn around and make 3 api calls using it.
        if @request_guid
          @request_guid = "#{@request_guid}::#{SecureRandom.uuid}"
        else
          @request_guid ||= SecureRandom.uuid
        end

        ::VCAP::Request.current_id = @request_guid
      end

      after do
        ::VCAP::Component.varz.synchronize do
          varz[:requests][:outstanding] -= 1
          varz[:requests][:completed] += 1
          varz[:http_status][response.status] += 1
        end
        headers['Content-Type'] = 'application/json;charset=utf-8'
        headers[::VCAP::Request::HEADER_NAME] = @request_guid
        ::VCAP::Request.current_id = nil
        nil
      end
    end

    private

    def self.init_varz
      ::VCAP::Component.varz.threadsafe!

      requests = {:outstanding => 0, :completed => 0}
      http_status = {}
      [(100..101), (200..206), (300..307), (400..417), (500..505)].each do |r|
        r.each { |c| http_status[c] = 0 }
      end
      recent_errors = ::VCAP::RingBuffer.new(50)
      vcap_sinatra = {
        :requests => requests,
        :http_status => http_status,
        :recent_errors => recent_errors
      }
      ::VCAP::Component.varz.synchronize do
        ::VCAP::Component.varz[:vcap_sinatra] ||= vcap_sinatra
      end
    end
  end
end
