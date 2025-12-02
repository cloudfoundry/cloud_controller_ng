module Fog
  module OpenStack
    module Core
      attr_accessor :auth_token
      attr_reader :unscoped_token
      attr_reader :openstack_cache_ttl
      attr_reader :auth_token_expiration
      attr_reader :current_user
      attr_reader :current_user_id
      attr_reader :current_tenant
      attr_reader :openstack_domain_name
      attr_reader :openstack_user_domain
      attr_reader :openstack_project_domain
      attr_reader :openstack_domain_id
      attr_reader :openstack_user_domain_id
      attr_reader :openstack_project_id
      attr_reader :openstack_project_domain_id
      attr_reader :openstack_identity_api_version
      attr_reader :openstack_application_credential_id
      attr_reader :openstack_application_credential_secret

      # fallback
      def self.not_found_class
        Fog::OpenStack::Compute::NotFound
      end

      def credentials
        options = {
          :provider             => 'openstack',
          :openstack_auth_url   => @openstack_auth_uri.to_s,
          :openstack_auth_token => @auth_token,
          :current_user         => @current_user,
          :current_user_id      => @current_user_id,
          :current_tenant       => @current_tenant,
          :unscoped_token       => @unscoped_token
        }
        openstack_options.merge options
      end

      def reload
        @connection.reset
      end

      def initialize(options = {})
        setup(options)
        authenticate
        @connection = Fog::Core::Connection.new(@openstack_management_url, @persistent, @connection_options)
      end

      private

      def request(params, parse_json = true)
        retried = false
        begin
          authenticate! if @expires && (@expires - Time.now.utc).to_i < 60

          response = @connection.request(
            params.merge(
              :headers => headers(params[:headers]),
              :path    => "#{@path}/#{params[:path]}"
            )
          )
        rescue Excon::Errors::Unauthorized, Excon::Error::Unauthorized => error
          # token expiration and token renewal possible
          if error.response.body != 'Bad username or password' && @openstack_can_reauthenticate && !retried
            authenticate!
            retried = true
            retry
          # bad credentials or token renewal not possible
          else
            raise error
          end
        rescue Excon::Errors::HTTPStatusError => error
          raise case error
                when Excon::Errors::NotFound
                  self.class.not_found_class.slurp(error)
                else
                  error
                end
        end

        if !response.body.empty? && response.get_header('Content-Type').match('application/json')
          # TODO: remove parse_json in favor of :raw_body
          response.body = Fog::JSON.decode(response.body) if parse_json && !params[:raw_body]
        end

        response
      end

      def set_microversion
        @microversion_key          ||= 'Openstack-API-Version'.freeze
        @microversion_service_type ||= @openstack_service_type.first

        @microversion = Fog::OpenStack.get_supported_microversion(
          @supported_versions,
          @openstack_management_uri,
          @auth_token,
          @connection_options
        ).to_s

        # choose minimum out of reported and supported version
        if microversion_newer_than?(@supported_microversion)
          @microversion = @supported_microversion
        end

        # choose minimum out of set and wished version
        if @fixed_microversion && microversion_newer_than?(@fixed_microversion)
          @microversion = @fixed_microversion
        elsif @fixed_microversion && @microversion != @fixed_microversion
          Fog::Logger.warning("Microversion #{@fixed_microversion} not supported")
        end
      end

      def microversion_newer_than?(version)
        Gem::Version.new(version) < Gem::Version.new(@microversion)
      end

      def headers(additional_headers)
        additional_headers ||= {}
        unless @microversion.nil? || @microversion.empty?
          microversion_value = if @microversion_key == 'Openstack-API-Version'
                                 "#{@microversion_service_type} #{@microversion}"
                               else
                                 @microversion
                               end
          microversion_header = {@microversion_key => microversion_value}
          additional_headers.merge!(microversion_header)
        end

        {
          'Content-Type' => 'application/json',
          'Accept'       => 'application/json',
          'X-Auth-Token' => @auth_token
        }.merge!(additional_headers)
      end

      def openstack_options
        options = {}
        # Create a hash of (:openstack_*, value) of all the @openstack_* instance variables
        instance_variables.select { |x| x.to_s.start_with? '@openstack' }.each do |openstack_param|
          option_name = openstack_param.to_s[1..-1]
          options[option_name.to_sym] = instance_variable_get openstack_param
        end
        options
      end

      def api_path_prefix
        path = ''
        if @openstack_management_uri && @openstack_management_uri.path != '/'
          path = @openstack_management_uri.path
        end
        unless default_path_prefix.empty?
          path << '/' + default_path_prefix
        end
        path
      end

      def default_endpoint_type
        'public'
      end

      def default_path_prefix
        ''
      end

      def setup(options)
        if options.respond_to?(:config_service?) && options.config_service?
          configure(options)
          return
        end

        # Create @openstack_* instance variables from all :openstack_* options
        options.select { |x| x.to_s.start_with? 'openstack' }.each do |openstack_param, value|
          instance_variable_set "@#{openstack_param}".to_sym, value
        end

        # Ensure OpenStack User's Password is always a String
        @openstack_api_key = @openstack_api_key.to_s if @openstack_api_key

        @auth_token ||= options[:openstack_auth_token]
        @openstack_must_reauthenticate = false
        @openstack_endpoint_type = options[:openstack_endpoint_type] || 'public'
        @openstack_cache_ttl = options[:openstack_cache_ttl] || 0

        if @auth_token
          @openstack_can_reauthenticate = false
        else
          missing_credentials = []
          unless @openstack_application_credential_secret and @openstack_application_credential_id
            missing_credentials << :openstack_api_key unless @openstack_api_key
            unless @openstack_username || @openstack_userid
              missing_credentials << 'openstack_username/openstack_userid or openstack_application_credential_secret and openstack_application_credential_id'
            end
          end
          unless missing_credentials.empty?
            raise ArgumentError, "Missing required arguments: #{missing_credentials.join(', ')}"
          end
          @openstack_can_reauthenticate = true
        end

        @current_user    = options[:current_user]
        @current_user_id = options[:current_user_id]
        @current_tenant  = options[:current_tenant]

        @openstack_service_type = options[:openstack_service_type] || default_service_type
        @openstack_endpoint_type = options[:openstack_endpoint_type] || default_endpoint_type
        @openstack_endpoint_type = @openstack_endpoint_type.gsub(/URL/, '')
        @connection_options = options[:connection_options] || {}
        @persistent = options[:persistent] || false
      end

      def authenticate
        if !@openstack_management_url || @openstack_must_reauthenticate
          @openstack_auth_token = nil if @openstack_must_reauthenticate

          token = Fog::OpenStack::Auth::Token.build(openstack_options, @connection_options)

          @openstack_management_url = if token.catalog && !token.catalog.payload.empty?
                                        token.catalog.get_endpoint_url(
                                          @openstack_service_type,
                                          @openstack_endpoint_type,
                                          @openstack_region
                                        )
                                      else
                                        @openstack_auth_url
                                      end

          @current_user = token.user['name']
          @current_user_id          = token.user['id']
          @current_tenant           = token.tenant
          @expires                  = Time.parse(token.expires)
          @auth_token               = token.token
          @unscoped_token           = token.token
          @openstack_must_reauthenticate = false
        else
          @auth_token = @openstack_auth_token
        end

        @openstack_management_uri = URI.parse(@openstack_management_url)

        # both need to be set in service's initialize for microversions to work
        set_microversion if @supported_microversion && @supported_versions
        @path = api_path_prefix

        true
      end

      def authenticate!
        @openstack_must_reauthenticate = true
        authenticate
      end
    end
  end
end
