module Fog
  module Google
    class Compute
      class UrlMaps < Fog::Collection
        model Fog::Google::Compute::UrlMap

        def all(opts = {})
          items = []
          next_page_token = nil
          loop do
            data = service.list_url_maps(**opts)
            next_items = data.to_h[:items] || []
            items.concat(next_items)
            next_page_token = data.next_page_token
            break if next_page_token.nil? || next_page_token.empty?
            opts[:page_token] = next_page_token
          end
          load(items)
        end

        def get(identity)
          if identity
            url_map = service.get_url_map(identity).to_h
            return new(**url_map)
          end
        rescue ::Google::Apis::ClientError => e
          raise e unless e.status_code == 404
          nil
        end
      end
    end
  end
end
