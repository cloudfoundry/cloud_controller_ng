module Fog
  module Google
    class Compute
      class SslCertificates < Fog::Collection
        model Fog::Google::Compute::SslCertificate

        def get(identity)
          if identity
            ssl_certificate = service.get_ssl_certificate(identity).to_h
            return new(ssl_certificate)
          end
        rescue ::Google::Apis::ClientError => e
          raise e unless e.status_code == 404
          nil
        end

        def all(opts = {})
          items = []
          next_page_token = nil
          loop do
            data = service.list_ssl_certificates(**opts)
            next_items = data.to_h[:items] || []
            items.concat(next_items)
            next_page_token = data.next_page_token
            break if next_page_token.nil? || next_page_token.empty?
            opts[:page_token] = next_page_token
          end
          load(items)
        end
      end
    end
  end
end
