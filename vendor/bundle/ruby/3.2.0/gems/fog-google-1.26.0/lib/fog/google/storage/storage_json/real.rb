# frozen_string_literal: true

module Fog
  module Google
    class StorageJSON
      class Real
        include Utils
        include Fog::Google::Shared

        attr_accessor :client
        attr_reader :storage_json

        def initialize(options = {})
          shared_initialize(options[:google_project], GOOGLE_STORAGE_JSON_API_VERSION, GOOGLE_STORAGE_JSON_BASE_URL)
          @options = options.dup
          options[:google_api_scope_url] = GOOGLE_STORAGE_JSON_API_SCOPE_URLS.join(" ")
          @host = options[:host] || "storage.googleapis.com"

          # TODO(temikus): Do we even need this client?
          @client = initialize_google_client(options)

          @storage_json = ::Google::Apis::StorageV1::StorageService.new
          apply_client_options(@storage_json, options)

          @storage_json.client_options.open_timeout_sec = options[:open_timeout_sec] if options[:open_timeout_sec]
          @storage_json.client_options.read_timeout_sec = options[:read_timeout_sec] if options[:read_timeout_sec]
          @storage_json.client_options.send_timeout_sec = options[:send_timeout_sec] if options[:send_timeout_sec]
        end

        def signature(params)
          string_to_sign = <<-DATA
#{params[:method]}
#{params[:headers]['Content-MD5']}
#{params[:headers]['Content-Type']}
#{params[:headers]['Date']}
DATA

          google_headers = {}
          canonical_google_headers = +""
          params[:headers].each do |key, value|
            google_headers[key] = value if key[0..6] == "x-goog-"
          end

          google_headers = google_headers.sort_by { |a| a[0] }
          google_headers.each do |key, value|
            canonical_google_headers << "#{key}:#{value}\n"
          end
          string_to_sign << canonical_google_headers.to_s

          canonical_resource = +"/"
          if subdomain = params.delete(:subdomain)
            canonical_resource << "#{CGI.escape(subdomain).downcase}/"
          end
          canonical_resource << params[:path].to_s
          canonical_resource << "?"
          (params[:query] || {}).each_key do |key|
            if %w(acl cors location logging requestPayment versions versioning).include?(key)
              canonical_resource << "#{key}&"
            end
          end
          canonical_resource.chop!
          string_to_sign << canonical_resource.to_s

          # TODO(temikus): make signer configurable or add ability to supply your own via lambda
          if !@storage_json.authorization.signing_key.nil?
            signed_string = default_signer(string_to_sign)
          else
            # If client doesn't contain signing key attempt to auth via IAM SignBlob API
            signed_string = iam_signer(string_to_sign)
          end

          Base64.encode64(signed_string).chomp!
        end

        private

        def google_access_id
          @google_access_id ||= get_google_access_id
        end

        ##
        # Fetches the google service account name
        #
        # @return [String] Service account name, typically needed for GoogleAccessId, e.g.
        #   my-account@project.iam.gserviceaccount
        # @raises [Fog::Errors::Error] If authorisation is incorrect or inapplicable for current action
        def get_google_access_id
          if @storage_json.authorization.is_a?(::Google::Auth::UserRefreshCredentials)
            raise Fog::Errors::Error.new("User / Application Default Credentials are not supported for storage"\
                                         "url signing, please use a service account or metadata authentication.")
          end

          if !@storage_json.authorization.issuer.nil?
            return @storage_json.authorization.issuer
          else
            get_access_id_from_metadata
          end
        end

        ##
        # Attempts to fetch the google service account name from metadata using Google::Cloud::Env
        #
        # @return [String] Service account name, typically needed for GoogleAccessId, e.g.
        #   my-account@project.iam.gserviceaccount
        # @raises [Fog::Errors::Error] If Metadata service is not available or returns an invalid response
        def get_access_id_from_metadata
          if @google_cloud_env.metadata?
            access_id = @google_cloud_env.lookup_metadata("instance", "service-accounts/default/email")
          else
            raise Fog::Errors::Error.new("Metadata service not available, unable to retrieve service account info.")
          end

          if access_id.nil?
            raise Fog::Errors::Error.new("Metadata service found but didn't return data." \
               "Please file a bug: https://github.com/fog/fog-google")
          end

          return access_id
        end

        ##
        # Default url signer using service account keys
        #
        # @param [String] string_to_sign Special collection of headers and options for V2 storage signing, e.g.:
        #
        #   StringToSign = HTTP_Verb + "\n" +
        #                  Content_MD5 + "\n" +
        #                  Content_Type + "\n" +
        #                  Expires + "\n" +
        #                  Canonicalized_Extension_Headers +
        #                  Canonicalized_Resource
        #
        #   See https://cloud.google.com/storage/docs/access-control/signed-urls-v2
        # @return [String] Signature binary blob
        def default_signer(string_to_sign)
          key = @storage_json.authorization.signing_key
          key = OpenSSL::PKey::RSA.new(@storage_json.authorization.signing_key) unless key.respond_to?(:sign)
          digest = OpenSSL::Digest::SHA256.new
          return key.sign(digest, string_to_sign)
        end

        # IAM client used for SignBlob API.
        # Lazily initialize this since it requires another authorization request.
        def iam_service
          return @iam_service if defined?(@iam_service)

          @iam_service = ::Google::Apis::IamcredentialsV1::IAMCredentialsService.new
          apply_client_options(@iam_service, @options)
          iam_options = @options.merge(google_api_scope_url: GOOGLE_STORAGE_JSON_IAM_API_SCOPE_URLS.join(" "))
          @iam_service.authorization = initialize_auth(iam_options)
          @iam_service
        end

        ##
        # Fallback URL signer using the IAM SignServiceAccountBlob API, see
        #   Google::Apis::IamcredentialsV1::IAMCredentialsService#sign_service_account_blob
        #
        # @param [String] string_to_sign Special collection of headers and options for V2 storage signing, e.g.:
        #
        #   StringToSign = HTTP_Verb + "\n" +
        #                  Content_MD5 + "\n" +
        #                  Content_Type + "\n" +
        #                  Expires + "\n" +
        #                  Canonicalized_Extension_Headers +
        #                  Canonicalized_Resource
        #
        #   See https://cloud.google.com/storage/docs/access-control/signed-urls-v2
        # @return [String] Signature binary blob
        def iam_signer(string_to_sign)
          request = ::Google::Apis::IamcredentialsV1::SignBlobRequest.new(
            payload: string_to_sign
          )

          resource = "projects/-/serviceAccounts/#{google_access_id}"
          response = iam_service.sign_service_account_blob(resource, request)

          return response.signed_blob
        end
      end
    end
  end
end
