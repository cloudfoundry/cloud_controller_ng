require "google-cloud-env"

module Fog
  module Google
    module Shared
      attr_reader :project, :api_version, :api_url

      ##
      # Initializes shared attributes
      #
      # @param [String] project Google Cloud Project
      # @param [String] api_version Google API version
      # @param [String] base_url Google API base url
      # @return [void]
      def shared_initialize(project, api_version, base_url)
        @project = project
        @api_version = api_version
        @api_url = base_url + api_version + "/projects/"
        # google-cloud-env allows us to figure out which GCP runtime we're running in and query metadata
        # e.g. whether we're running in GCE/GKE/AppEngine or what region the instance is running in
        @google_cloud_env = ::Google::Cloud::Env.get
      end

      ##
      # Initializes the Google API Client
      #
      # @param [Hash] options Google API options
      # @option options [Bool]   :google_application_default Explicitly use application default credentials
      # @option options [Google::Auth|Signet] :google_auth Manually created authorization to use
      # @option options [String] :google_json_key_location The location of a JSON key file
      # @option options [String] :google_json_key_string The content of the JSON key file
      # @option options [String] :google_api_scope_url The access scope URLs
      # @option options [String] :app_name The app name to set in the user agent
      # @option options [String] :app_version The app version to set in the user agent
      # @option options [Hash] :google_client_options A hash to send additional options to Google API Client
      # @return [Google::APIClient] Google API Client
      # @raises [ArgumentError] If there is any missing argument
      def initialize_google_client(options)
        # NOTE: loaded here to avoid requiring this as a core Fog dependency
        begin
          # TODO: google-api-client is in gemspec now, re-assess if this initialization logic is still needed
          require "google/apis/monitoring_#{Fog::Google::Monitoring::GOOGLE_MONITORING_API_VERSION}"
          require "google/apis/compute_#{Fog::Google::Compute::GOOGLE_COMPUTE_API_VERSION}"
          require "google/apis/dns_#{Fog::Google::DNS::GOOGLE_DNS_API_VERSION}"
          require "google/apis/pubsub_#{Fog::Google::Pubsub::GOOGLE_PUBSUB_API_VERSION}"
          require "google/apis/sqladmin_#{Fog::Google::SQL::GOOGLE_SQL_API_VERSION}"
          require "google/apis/storage_#{Fog::Google::StorageJSON::GOOGLE_STORAGE_JSON_API_VERSION}"
          require "google/apis/iamcredentials_#{Fog::Google::StorageJSON::GOOGLE_STORAGE_JSON_IAM_API_VERSION}"
          require "googleauth"
        rescue LoadError => e
          Fog::Errors::Error.new("Please install the google-api-client (>= 0.9) gem before using this provider")
          raise e
        end

        validate_client_options(options)

        application_name = "fog"
        unless options[:app_name].nil?
          application_name = "#{options[:app_name]}/#{options[:app_version] || '0.0.0'} fog"
        end

        ::Google::Apis::ClientOptions.default.application_name = application_name
        ::Google::Apis::ClientOptions.default.application_version = Fog::Google::VERSION

        if ENV["DEBUG"]
          ::Google::Apis.logger = ::Logger.new(::STDERR)
          ::Google::Apis.logger.level = ::Logger::DEBUG
        end

        initialize_auth(options).tap do |auth|
          ::Google::Apis::RequestOptions.default.authorization = auth
        end
      end

      def initialize_auth(options)
        if options[:google_json_key_location] || options[:google_json_key_string]
          process_key_auth(options)
        elsif options[:google_auth]
          options[:google_auth]
        elsif options[:google_application_default]
          process_application_default_auth(options)
        else
          process_fallback_auth(options)
        end
      end

      ##
      # Applies given options to the client instance
      #
      # @param [Google::Apis::Core::BaseService] service API service client instance
      # @param [Hash] options (all ignored a.t.m., except :google_client_options)
      # @return [void]
      def apply_client_options(service, options = {})
        google_client_options = options[:google_client_options]
        return if google_client_options.nil? || google_client_options.empty?

        (service.client_options.members & google_client_options.keys).each do |option|
          service.client_options[option] = google_client_options[option]
        end
      end

      ##
      # Executes a request and wraps it in a result object
      #
      # @param [Google::APIClient::Method] api_method The method object or the RPC name of the method being executed
      # @param [Hash] parameters The parameters to send to the method
      # @param [Hash] body_object The body object of the request
      # @return [Excon::Response] The result from the API
      def request(api_method, parameters, body_object = nil, media = nil)
        client_parms = {
          :api_method => api_method,
          :parameters => parameters
        }
        # The Google API complains when given null values for enums, so just don't pass it any null fields
        # XXX It may still balk if we have a nested object, e.g.:
        #   {:a_field => "string", :a_nested_field => { :an_empty_nested_field => nil } }
        client_parms[:body_object] = body_object.reject { |_k, v| v.nil? } if body_object
        client_parms[:media] = media if media

        result = @client.execute(client_parms)

        build_excon_response(result.body.nil? || result.body.empty? ? nil : Fog::JSON.decode(result.body), result.status)
      end

      ##
      # Builds an Excon response
      #
      # @param [Hash] Response body
      # @param [Integer] Response status
      # @return [Excon::Response] Excon response
      def build_excon_response(body, status = 200)
        response = Excon::Response.new(:body => body, :status => status)
        if body && body.key?("error")
          msg = "Google Cloud did not return an error message"

          if body["error"].is_a?(Hash)
            response.status = body["error"]["code"]
            if body["error"].key?("errors")
              msg = body["error"]["errors"].map { |error| error["message"] }.join(", ")
            elsif body["error"].key?("message")
              msg = body["error"]["message"]
            end
          elsif body["error"].is_a?(Array)
            msg = body["error"].map { |error| error["code"] }.join(", ")
          end

          case response.status
          when 404
            raise Fog::Errors::NotFound.new(msg)
          else
            raise Fog::Errors::Error.new(msg)
          end
        end

        response
      end

      private

      # Helper method to process application default authentication
      #
      # @param [Hash]  options - client options hash
      # @return [Google::Auth::DefaultCredentials] - google auth object
      def process_application_default_auth(options)
        ::Google::Auth.get_application_default(options[:google_api_scope_url])
      end

      # Helper method to process fallback authentication
      # Current fallback is application default authentication
      #
      # @param [Hash]  options - client options hash
      # @return [Google::Auth::DefaultCredentials] - google auth object
      def process_fallback_auth(options)
        Fog::Logger.warning(
          "Didn't detect any client auth settings, " \
          "trying to fall back to application default credentials..."
        )
        begin
          return process_application_default_auth(options)
        rescue StandardError
          raise Fog::Errors::Error.new(
            "Fallback auth failed, could not configure authentication for Fog client.\n" \
              "Check your auth options, must be one of:\n" \
              "- :google_json_key_location,\n" \
              "- :google_json_key_string,\n" \
              "- :google_auth,\n" \
              "- :google_application_default,\n" \
              "If credentials are valid - please, file a bug to fog-google." \
          )
        end
      end

      # Helper method to process key authentication
      #
      # @param [Hash]  options - client options hash
      # @return [Google::Auth::ServiceAccountCredentials] - google auth object
      def process_key_auth(options)
        if options[:google_json_key_location]
          json_key = File.read(File.expand_path(options[:google_json_key_location]))
        elsif options[:google_json_key_string]
          json_key = options[:google_json_key_string]
        end

        validate_json_credentials(json_key)

        ::Google::Auth::ServiceAccountCredentials.make_creds(
          :json_key_io => StringIO.new(json_key),
          :scope => options[:google_api_scope_url]
        )
      end

      # Helper method to sort out deprecated and missing auth options
      #
      # @param [Hash]  options - client options hash
      def validate_client_options(options)
        # Users can no longer provide their own clients due to rewrite of auth
        # in https://github.com/google/google-api-ruby-client/ version 0.9.
        if options[:google_client]
          raise ArgumentError.new("Deprecated argument no longer works: google_client")
        end

        # They can also no longer use pkcs12 files, because Google's new auth
        # library doesn't support them either.
        if options[:google_key_location]
          raise ArgumentError.new("Deprecated auth method no longer works: google_key_location")
        end
        if options[:google_key_string]
          raise ArgumentError.new("Deprecated auth method no longer works: google_key_string")
        end

        # Google client email option is no longer needed
        if options[:google_client_email]
          Fog::Logger.deprecation("Argument no longer needed for auth: google_client_email")
        end

        # Validate required arguments
        unless options[:google_api_scope_url]
          raise ArgumentError.new("Missing required arguments: google_api_scope_url")
        end
      end

      # Helper method to checks whether the necessary fields are present in
      # JSON key credentials
      #
      # @param [String]  json_key - Google json auth key string
      def validate_json_credentials(json_key)
        json_key_hash = Fog::JSON.decode(json_key)

        unless json_key_hash.key?("client_email") || json_key_hash.key?("private_key")
          raise ArgumentError.new("Invalid Google JSON key")
        end
      end
    end
  end
end
