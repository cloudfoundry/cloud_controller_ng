module Fog
  module Google
    class Compute
      class Operations < Fog::Collection
        model Fog::Google::Compute::Operation

        def all(zone: nil, region: nil, filter: nil, max_results: nil,
                order_by: nil, page_token: nil)
          opts = {
            :filter => filter,
            :max_results => max_results,
            :order_by => order_by,
            :page_token => page_token
          }
          items = []
          next_page_token = nil
          loop do
            if zone
              data = service.list_zone_operations(zone, **opts)
              next_items = data.to_h[:items] || []
              items.concat(next_items)
              next_page_token = data.next_page_token
            elsif region
              data = service.list_region_operations(region, **opts)
              next_items = data.to_h[:items] || []
              items.concat(next_items)
              next_page_token = data.next_page_token
            else
              data = service.list_global_operations(**opts)
              next_items = data.to_h[:items] || []
              items.concat(next_items)
              next_page_token = data.next_page_token
            end
            break if next_page_token.nil? || next_page_token.empty?
            opts[:page_token] = next_page_token
          end

          load(items)
        end

        def get(identity, zone = nil, region = nil)
          if !zone.nil?
            operation = service.get_zone_operation(zone, identity).to_h
            return new(operation)
          elsif !region.nil?
            operation = service.get_region_operation(region, identity).to_h
            return new(operation)
          elsif identity
            operation = service.get_global_operation(identity).to_h
            return new(operation)
          end
        rescue ::Google::Apis::ClientError => e
          raise e unless e.status_code == 404
          nil
        end
      end
    end
  end
end
