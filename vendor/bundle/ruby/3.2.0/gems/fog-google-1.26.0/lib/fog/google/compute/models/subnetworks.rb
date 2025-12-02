module Fog
  module Google
    class Compute
      class Subnetworks < Fog::Collection
        model Fog::Google::Compute::Subnetwork

        def all(region: nil, filter: nil, max_results: nil, order_by: nil, page_token: nil)
          filters = {
            :filter => filter,
            :max_results => max_results,
            :order_by => order_by,
            :page_token => page_token
          }
          items = []
          next_page_token = nil
          loop do
            if region
              data = service.list_subnetworks(region, **filters)
              next_items = data.items || []
              items.concat(next_items)
              next_page_token = data.next_page_token
            else
              data = service.list_aggregated_subnetworks(**filters)
              data.items.each_value do |region_obj|
                items.concat(region_obj.subnetworks) if region_obj && region_obj.subnetworks
              end
            end
            break if next_page_token.nil? || next_page_token.empty?
            filters[:page_token] = next_page_token
          end
          load(items.map(&:to_h))
        end

        def get(identity, region = nil)
          if region
            subnetwork = service.get_subnetwork(identity, region).to_h
            return new(subnetwork)
          elsif identity
            response = all(:filter => "name eq #{identity}",
                           :max_results => 1)
            subnetwork = response.first unless response.empty?
            return subnetwork
          end
        rescue ::Google::Apis::ClientError => e
          raise e unless e.status_code == 404
          nil
        end
      end
    end
  end
end
