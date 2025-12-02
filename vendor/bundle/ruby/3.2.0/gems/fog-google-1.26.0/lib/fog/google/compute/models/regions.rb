module Fog
  module Google
    class Compute
      class Regions < Fog::Collection
        model Fog::Google::Compute::Region

        def all(opts = {})
          items = []
          next_page_token = nil
          loop do
            data = service.list_regions(**opts)
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
            region = service.get_region(identity).to_h
            return new(region)
          end
        rescue ::Google::Apis::ClientError => e
          raise e unless e.status_code == 404
          nil
        end
      end
    end
  end
end
