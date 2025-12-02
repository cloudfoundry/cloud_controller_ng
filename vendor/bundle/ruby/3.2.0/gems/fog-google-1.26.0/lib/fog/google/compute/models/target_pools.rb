module Fog
  module Google
    class Compute
      class TargetPools < Fog::Collection
        model Fog::Google::Compute::TargetPool

        def all(region: nil, filter: nil, max_results: nil, order_by: nil, page_token: nil)
          opts = {
            :filter => filter,
            :max_results => max_results,
            :order_by => order_by,
            :page_token => page_token
          }
          items = []
          next_page_token = nil
          loop do
            if region.nil?
              data = service.list_aggregated_target_pools(**opts)
              data.items.each_value do |lst|
                items.concat(lst.to_h[:target_pools]) if lst && lst.target_pools
              end
              next_page_token = data.next_page_token
            else
              data = service.list_target_pools(region, **opts)
              next_items = data.to_h[:items] || []
              items.concat(next_items)
              next_page_token = data.next_page_token
            end
            break if next_page_token.nil? || next_page_token.empty?
            opts[:page_token] = next_page_token
          end
          load(items)
        end

        def get(identity, region = nil)
          if region
            target_pool = service.get_target_pool(identity, region).to_h
            return new(target_pool)
          elsif identity
            response = all(:filter => "name eq #{identity}")
            target_pool = response.first unless response.empty?
            return target_pool
          end
        rescue ::Google::Apis::ClientError => e
          raise e unless e.status_code = 404
          nil
        end
      end
    end
  end
end
