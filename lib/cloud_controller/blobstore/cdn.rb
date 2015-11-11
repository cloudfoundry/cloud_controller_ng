module CloudController
  module Blobstore
    class Cdn
      def self.make(host)
        return nil if host.nil? || host == ''
        new(host)
      end

      attr_reader :host

      def initialize(host)
        @host = host
      end

      def get(path, &block)
        HTTPClient.new.get(download_uri(path)) do |chunk|
          block.yield chunk
        end
      end

      def download_uri(path)
        url = "#{host}/#{path}"
        url = Aws::CF::Signer.sign_url(url) if Aws::CF::Signer.is_configured?
        url
      end

      # Don't call new directly because there's logic in .make
      private_class_method(:new)
    end
  end
end
