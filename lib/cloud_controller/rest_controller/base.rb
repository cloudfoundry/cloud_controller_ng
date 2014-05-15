require "cloud_controller/rest_controller/common_params"

module VCAP::CloudController::RestController

  # The base class for all api endpoints.
  class Base
    ROUTE_PREFIX = "/v2"

    include VCAP::CloudController
    include VCAP::Errors
    include VCAP::RestAPI
    include Messages
    include Routes
    extend Forwardable

    def_delegators :@sinatra, :redirect

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
    def initialize(config, logger, env, params, body, sinatra = nil, dependencies = {})
      @config  = config
      @logger  = logger
      @env     = env
      @params  = params
      @body    = body
      common_params = CommonParams.new(logger)
      @opts    = common_params.parse(params)
      @sinatra = sinatra

      inject_dependencies(dependencies)
    end

    # Override this to set dependencies
    #
    def inject_dependencies(dependencies = {})
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
      logger.debug "cc.dispatch", endpoint: op, args: args
      check_authentication(op)
      send(op, *args)
    rescue Sequel::ValidationFailed => e
      raise self.class.translate_validation_exception(e, request_attrs)
    rescue Sequel::HookFailed => e
      raise VCAP::Errors::ApiError.new_from_details("InvalidRequest", e.message)
    rescue Sequel::DatabaseError => e
      raise self.class.translate_and_log_exception(logger, e)
    rescue JsonMessage::Error => e
      logger.debug("Rescued JsonMessage::Error at #{__FILE__}:#{__LINE__}\n#{e.inspect}\n#{e.backtrace.join("\n")}")
      raise VCAP::Errors::ApiError.new_from_details("MessageParseError", e)
    rescue VCAP::Errors::InvalidRelation => e
      raise VCAP::Errors::ApiError.new_from_details("InvalidRelation", e)
    end

    # Fetch the current active user.  May be nil
    #
    # @return [User] User object for the currently active user
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

    def add_warning(warning)
      escaped_warning = CGI.escape(warning)
      existing_warning = @sinatra.headers['X-Cf-Warnings']

      new_warning = existing_warning.nil? ?
          escaped_warning : "#{existing_warning},#{escaped_warning}"

      set_header('X-Cf-Warnings', new_warning)
    end

    def check_authentication(op)
      # The logic here is a bit oddly ordered, but it supports the
      # legacy calls setting a user, but not providing a token.
      return if self.class.allow_unauthenticated_access?(op)
      return if VCAP::CloudController::SecurityContext.current_user
      return if VCAP::CloudController::SecurityContext.admin?

      if VCAP::CloudController::SecurityContext.missing_token?
        raise VCAP::Errors::ApiError.new_from_details('NotAuthenticated')
      elsif VCAP::CloudController::SecurityContext.invalid_token?
        raise VCAP::Errors::ApiError.new_from_details('InvalidAuthToken')
      else
        logger.error "Unexpected condition: valid token with no user/client id " +
                       "or admin scope. Token hash: #{VCAP::CloudController::SecurityContext.token}"
        raise VCAP::Errors::ApiError.new_from_details('InvalidAuthToken')
      end
    end

    def v2_api?
      env["PATH_INFO"] =~ /^#{ROUTE_PREFIX}/
    end

    def recursive?
      params["recursive"] == "true"
    end

    def async?
      params["async"] == "true"
    end

    # hook called before +create+
    def before_create
    end

    # hook called after +create+
    def after_create(obj)
    end

    # hook called before +update+, +add_related+ or +remove_related+
    def before_update(obj)
    end

    # hook called after +update+, +add_related+ or +remove_related+
    def after_update(obj)
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
        @path_base ||= class_basename.underscore.sub(/_controller$/, '')
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
        @query_parameters ||= Set.new
        @query_parameters |= Set.new(args.map { |a| a.to_s }) unless args.empty?
        @query_parameters
      end

      # Query params that will be preserved in next and prev urls while doing enum
      #
      # @param [Array] args One or more param keys that will be preserved in next
      # and prev urls
      #
      # @return [Set] If called with no arguments, returns the list
      # of preserve query parameters.
      def preserve_query_parameters(*args)
        @perserved_query_params ||= Set.new
        @perserved_query_params |= args.map { |a| a.to_s } unless args.empty?
        @perserved_query_params
      end

      def deprecated_endpoint(path)
        controller.after "#{path}*" do
          headers["X-Cf-Warnings"] ||= CGI.escape("Endpoint deprecated")
        end
      end

      def allow_unauthenticated_access(options={})
        if options[:only]
          @allow_unauthenticated_access_ops = Array(options[:only])
        else
          @allow_unauthenticated_access_to_all_ops = true
        end
      end

      def authenticate_basic_auth(path, &block)
        controller.before path do
          auth = Rack::Auth::Basic::Request.new(env)
          unless auth.provided? && auth.basic? && auth.credentials == block.call
            raise Errors::ApiError.new_from_details("NotAuthorized")
          end
        end
      end

      def allow_unauthenticated_access?(op)
        if @allow_unauthenticated_access_to_all_ops
          @allow_unauthenticated_access_to_all_ops
        elsif @allow_unauthenticated_access_ops
          @allow_unauthenticated_access_ops.include?(op)
        end
      end

      def translate_and_log_exception(logger, e)
        msg = ["exception not translated: #{e.class} - #{e.message}"]
        msg[0] = msg[0] + ":"
        msg.concat(e.backtrace).join("\\n")
        logger.warn(msg.join("\\n"))
        Errors::ApiError.new_from_details("InvalidRequest")
      end
    end
  end
end
