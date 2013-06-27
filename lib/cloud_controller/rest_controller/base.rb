# Copyright (c) 2009-2012 VMware, Inc.

module VCAP::CloudController::RestController

  # The base class for all api endpoints.
  class Base
    ROUTE_PREFIX = "/v2"

    include VCAP::CloudController
    include VCAP::Errors
    include VCAP::RestAPI
    include PermissionManager
    include Messages
    include Routes
    extend Forwardable

    def_delegators :@sinatra, :redirect

    # Tell the PermissionManager the types of operations that can be performed.
    define_permitted_operation :create
    define_permitted_operation :read
    define_permitted_operation :update
    define_permitted_operation :delete
    define_permitted_operation :enumerate

    # Create a new rest api endpoint.
    #
    # @param [Hash] config CC configuration
    #
    # @param [Steno::Logger] logger The logger to use during the request.
    #
    # @param [Hash] env The http environment for the request.
    #
    # @param [Hash] params The http query parms and/or the parameters in a
    # multipart post.
    #
    # @param [IO] body The request body.
    #
    # @param [Sinatra::Base] sinatra The sinatra object associated with the
    # request.
    #
    # We had been trying to keep everything relatively framework
    # agnostic in the base api and everthing build on it, but, the need to call
    # send_file changed that.
    #
    def initialize(config, logger, env, params, body, sinatra = nil)
      @config  = config
      @logger  = logger
      @env     = env
      @params  = params
      @body    = body
      @opts    = parse_params(params)
      @sinatra = sinatra
    end

    # Parses and sanitizes query parameters from the sinatra request.
    #
    # @return [Hash] the parsed parameter hash
    def parse_params(params)
      logger.debug "parse_params: #{params}"
      # FIXME: replace with URI parse on the query string.
      # Sinatra squshes duplicate query parms into a single entry rather
      # than an array (which we might have for q)
      res = {}
      [ [ "inline-relations-depth", Integer ],
        [ "page",                   Integer ],
        [ "results-per-page",       Integer ],
        [ "q",                      String  ]
      ].each do |key, klass|
        val = params[key]
        res[key.underscore.to_sym] = Object.send(klass.name, val) if val
      end
      res
    end

    def parse_date_param(param)
      str = @params[param]
      Time.parse(str).localtime if str
    rescue
      raise Errors::BadQueryParameter
    end

    # Main entry point for the rest routes.  Acts as the final location
    # for catching any unhandled sequel and db exceptions.  By calling
    # translate_and_log_exception, they will get logged so that we can
    # address them and will get converted to a generic invalid request
    # so that they can be investigated and have more accurate error
    # reporting added.
    #
    # @param [Symbol] op The method to dispatch to.
    #
    # @param [Array] args The arguments to the method being dispatched to.
    #
    # @return [Object] Returns an array of [http response code, Header hash,
    # body string], or just a body string.
    def dispatch(op, *args)
      logger.debug "dispatch: #{op}"
      check_authentication
      send(op, *args)
    rescue Sequel::ValidationFailed => e
      raise self.class.translate_validation_exception(e, request_attrs)
    rescue Sequel::DatabaseError => e
      raise self.class.translate_and_log_exception(logger, e)
    rescue JsonMessage::Error => e
      raise MessageParseError.new(e)
    rescue Models::InvalidRelation => e
      raise InvalidRelation.new(e)
    rescue VCAP::Errors::Error => e
      raise
    rescue => e
      logger.error(["An unhandled exception has occurred #{e.class} - #{e.message}:"].concat(e.backtrace).join("\\n"))
      raise Errors::ServerError
    end

    # Fetch the current active user.  May be nil
    #
    # @return [Models::User] User object for the currently active user
    def user
      VCAP::CloudController::SecurityContext.current_user
    end

    # Fetch the current roles in a Roles object.
    #
    # @return [Roles] Roles object that can be queried for roles
    def roles
      VCAP::CloudController::SecurityContext.roles
    end

    # see Sinatra::Base#send_file
    def send_file(path, opts={})
      @sinatra.send_file(path, opts)
    end

    def set_header(name, value)
      @sinatra.headers[name] = value
    end

    def check_authentication
      # The logic here is a bit oddly ordered, but it supports the
      # legacy calls setting a user, but not providing a token.
      return if self.class.allow_unauthenticated_access?
      return if VCAP::CloudController::SecurityContext.current_user
      return if VCAP::CloudController::SecurityContext.current_user_is_admin?

      if VCAP::CloudController::SecurityContext.token
        raise NotAuthorized
      else
        raise InvalidAuthToken
      end
    end

    def v2_api?
      env["PATH_INFO"] =~ /#{ROUTE_PREFIX}/i
    end

    attr_reader :config, :logger, :env, :params, :body, :request_attrs

    class << self
      include VCAP::CloudController

      # basename of the class
      #
      # @return [String] basename of the class
      def class_basename
        self.name.split("::").last
      end

      # path
      #
      # @return [String] The path/route to the collection associated with
      # the class.
      def path
        "#{ROUTE_PREFIX}/#{path_base}"
      end

      # Get and set the base of the path for the api endpoint.
      #
      # @param [String] base path to the api endpoint, e.g. the apps part of
      # /v2/apps/...
      #
      # @return [String] base path to the api endpoint
      def path_base(base = nil)
        @path_base = base if base
        @path_base || class_basename.underscore.pluralize
      end

      # Get and set the allowed query parameters (sent via the q http
      # query parameter) for this rest/api endpoint.
      #
      # @param [Array] args One or more attributes that can be used
      # as query parameters.
      #
      # @return [Set] If called with no arguments, returns the list
      # of query parameters.
      def query_parameters(*args)
        if args.empty?
          @query_parameters ||= Set.new
        else
          @query_parameters ||= Set.new
          @query_parameters |= Set.new(args.map { |a| a.to_s })
        end
      end

      # Disable the generation of default routes
      def disable_default_routes
        @disable_default_routes = true
      end

      def allow_unauthenticated_access
        @allow_unauthenticated_access = true
      end

      def allow_unauthenticated_access?
        @allow_unauthenticated_access
      end

      # Returns true if the cc framework should generate default routes for an
      # api endpoint.  If this is false, the api is expected to generate
      # its own routes.
      def default_routes?
        !@disable_default_routes
      end

      def translate_and_log_exception(logger, e)
        msg = ["exception not translated: #{e.class} - #{e.message}"]
        msg[0] = msg[0] + ":"
        msg.concat(e.backtrace).join("\\n")
        logger.warn(msg.join("\\n"))
        Errors::InvalidRequest
      end
    end
  end
end
