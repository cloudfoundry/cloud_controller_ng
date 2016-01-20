module CloudController
  module Blobstore
    class NginxSecureLinkSigner
      def initialize(secret:, internal_host:, internal_path_prefix: nil, public_host:, public_path_prefix: nil)
        @secret               = secret
        @internal_host        = internal_host
        @internal_path_prefix = internal_path_prefix
        @public_host          = public_host
        @public_path_prefix   = public_path_prefix
      end

      def sign_internal_url(expires:, path:)
        path       = File.join([@internal_path_prefix, path].compact)
        md5        = generate_md5(@secret, expires, path)
        url        = URI(@internal_host)
        url.scheme = 'http'
        url.path   = path
        url.query  = { md5: md5, expires: expires }.to_query
        url.to_s
      end

      def sign_public_url(expires:, path:)
        path       = File.join([@public_path_prefix, path].compact)
        md5        = generate_md5(@secret, expires, path)
        url        = URI(@public_host)
        url.scheme = 'https'
        url.path   = path
        url.query  = { md5: md5, expires: expires }.to_query
        url.to_s
      end

      private

      def generate_md5(secret, expires, path)
        # using nginx secure link generation
        # see: http://nginx.org/en/docs/http/ngx_http_secure_link_module.html
        #
        # from that site, the bash generation is:
        #  echo -n '1199192400/fo/ob/bar some-secret' | \
        #  openssl md5 -binary | openssl base64 | tr +/ -_ | tr -d =

        s   = "#{expires}#{path} #{secret}"
        enc = Base64.encode64(Digest::MD5.digest(s))
        enc.tr('+/', '-_').delete('=').chomp
      end
    end
  end
end
