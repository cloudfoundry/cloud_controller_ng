module Fog
  module Google
    class Compute
      class MachineTypes < Fog::Collection
        model Fog::Google::Compute::MachineType

        def all(zone: nil, filter: nil, max_results: nil, order_by: nil, page_token: nil)
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
              data = service.list_machine_types(zone, **opts)
              next_items = data.items || []
              items.concat(next_items)
              next_page_token = data.next_page_token
            else
              data = service.list_aggregated_machine_types(**opts)
              data.items.each_value do |scoped_list|
                items.concat(scoped_list.machine_types) if scoped_list && scoped_list.machine_types
              end
              next_page_token = data.next_page_token
            end
            break if next_page_token.nil? || next_page_token.empty?
            opts[:page_token] = next_page_token
          end
          load(items.map(&:to_h) || [])
        end

        def get(identity, zone = nil)
          if zone
            machine_type = service.get_machine_type(identity, zone).to_h
            return new(machine_type)
          elsif identity
            # This isn't very functional since it just shows the first available
            # machine type globally, but needed due to overall compatibility
            # See: https://github.com/fog/fog-google/issues/352
            response = all(:filter => "name eq #{identity}",
                           :max_results => 1)
            machine_type = response.first unless response.empty?
            return machine_type
          end
        rescue ::Google::Apis::ClientError => e
          raise e unless e.status_code == 404
          nil
        end
      end
    end
  end
end
