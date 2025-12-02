module Fog
  module Google
    class Compute
      class Zones < Fog::Collection
        model Fog::Google::Compute::Zone

        def all(opts = {})
          items = []
          next_page_token = nil
          loop do
            data = service.list_zones
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
            zone = service.get_zone(identity).to_h
            new(zone)
          end
        rescue ::Google::Apis::ClientError => e
          raise e unless e.status_code == 404
          nil
        end
      end
    end
  end
end
