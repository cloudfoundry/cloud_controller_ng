module Fog
  module Google
    class Compute
      class ForwardingRules < Fog::Collection
        model Fog::Google::Compute::ForwardingRule

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
            if region
              data = service.list_forwarding_rules(region, **opts)
              next_items = data.items || []
              items.concat(next_items)
              next_page_token = data.next_page_token
            else
              data = service.list_aggregated_forwarding_rules(**opts)
              data.items.each_value do |scoped_list|
                items.concat(scoped_list.forwarding_rules) if scoped_list && scoped_list.forwarding_rules
              end
              next_page_token = data.next_page_token
            end
            break if next_page_token.nil? || next_page_token.empty?
            opts[:page_token] = next_page_token
          end
          load(items.map(&:to_h))
        end

        def get(identity, region = nil)
          if region
            forwarding_rule = service.get_forwarding_rule(identity, region).to_h
            return new(forwarding_rule)
          elsif identity
            response = all(
              :filter => "name eq #{identity}", :max_results => 1
            )
            forwarding_rule = response.first unless response.empty?
            return forwarding_rule
          end
        end
      end
    end
  end
end
