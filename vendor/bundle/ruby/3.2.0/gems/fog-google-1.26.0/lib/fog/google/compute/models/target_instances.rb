module Fog
  module Google
    class Compute
      class TargetInstances < Fog::Collection
        model Fog::Google::Compute::TargetInstance

        def all(zone: nil, filter: nil, max_results: nil, order_by: nil,
                page_token: nil)
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
              data = service.list_target_instances(zone, **opts)
              next_items = data.to_h[:items] || []
              items.concat(next_items)
              next_page_token = data.next_page_token
            else
              data = service.list_aggregated_target_instances(**opts)
              data.items.each_value do |scoped_list|
                items.concat(scoped_list.target_instances.map(&:to_h)) if scoped_list && scoped_list.target_instances
              end
              next_page_token = data.next_page_token
            end
            break if next_page_token.nil? || next_page_token.empty?
            opts[:page_token] = next_page_token
          end
          load(items)
        end

        def get(identity, zone = nil)
          if zone
            target_instance = service.get_target_instance(target_instance, zone).to_h
            return new(target_instance)
          elsif identity
            response = all(:filter => "name eq #{identity}",
                           :max_results => 1)
            target_instance = response.first unless response.empty?
            return target_instance
          end
        rescue ::Google::Apis::ClientError => e
          raise e unless e.status_code == 404
          nil
        end
      end
    end
  end
end
