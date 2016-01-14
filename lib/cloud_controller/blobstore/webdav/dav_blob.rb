module CloudController
  module Blobstore
    class DavBlob < Blob
      attr_reader :url

      def initialize(httpmessage:, url:, secret:)
        @httpmessage = httpmessage
        @url         = URI(url)
        @secret      = secret
      end

      def download_url
        expires = Time.now.utc.to_i + 3600
        md5     = generate_nginx_secure_link_md5(@secret, expires, @url.path)

        url       = @url.dup
        url.query = { md5: md5, expires: expires }.to_query
        url.to_s
      end

      def attributes(*keys)
        @attributes ||= {
          etag:           @httpmessage.headers['ETag'],
          last_modified:  @httpmessage.headers['Last-Modified'],
          content_length: @httpmessage.headers['Content-Length'],
          created_at:     nil
        }

        return @attributes if keys.empty?
        @attributes.select { |key, _| keys.include? key }
      end

      private

      def generate_nginx_secure_link_md5(secret, expires, path)
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
