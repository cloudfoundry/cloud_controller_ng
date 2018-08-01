require 'cloud_controller/blobstore/webdav/http_client_provider'

module CloudController
  module Blobstore
    class NginxSecureLinkSigner
      def self.build(options:, directory_key:)
        NginxSecureLinkSigner.new(
          internal_endpoint:    options[:private_endpoint],
          internal_path_prefix: directory_key,
          public_endpoint:      options[:public_endpoint],
          public_path_prefix:   directory_key,
          basic_auth_user:      options[:username],
          basic_auth_password:  options[:password],
          httpclient:           HTTPClientProvider.provide(ca_cert_path: options[:ca_cert_path]),
        )
      end

      def initialize(internal_endpoint:, internal_path_prefix: nil,
        public_endpoint:, public_path_prefix: nil, basic_auth_user:, basic_auth_password:, httpclient:)

        @internal_uri             = URI(internal_endpoint)
        @internal_path_prefix     = internal_path_prefix
        @public_uri               = URI(public_endpoint)
        @public_path_prefix       = public_path_prefix
        @client                   = httpclient
        @headers                  = {}
        @headers['Authorization'] = 'Basic ' + Base64.strict_encode64("#{basic_auth_user}:#{basic_auth_password}").strip
      end

      def sign_internal_url(expires:, path:)
        request_uri  = uri(expires: expires, path: File.join([@internal_path_prefix, path].compact))
        response_uri = make_request(uri: request_uri)

        signed_uri        = @internal_uri.clone
        signed_uri.scheme = 'https'
        signed_uri.path   = response_uri.path
        signed_uri.query  = response_uri.query
        signed_uri.to_s
      end

      def sign_public_url(expires:, path:)
        request_uri  = uri(expires: expires, path: File.join([@public_path_prefix, path].compact))
        response_uri = make_request(uri: request_uri)

        signed_uri        = @public_uri.clone
        signed_uri.scheme = 'https'
        signed_uri.path   = response_uri.path
        signed_uri.query  = response_uri.query
        signed_uri.to_s
      end

      private

      def make_request(uri:)
        response = @client.get(uri, header: @headers)

        raise SigningRequestError.new("Could not get a signed url, #{response.status}/#{response.content}") unless response.status == 200

        URI(response.content)
      rescue OpenSSL::SSL::SSLError => e
        err = SigningRequestError.new("Could not get a signed url: #{e.message}")
        err.set_backtrace(e.backtrace)
        raise err
      end

      def uri(expires:, path:)
        uri       = @internal_uri.clone
        uri.path  = '/sign'
        uri.query = {
          expires: expires,
          path:    File.join(['/', path])
        }.to_query

        uri.to_s
      end
    end
  end
end
