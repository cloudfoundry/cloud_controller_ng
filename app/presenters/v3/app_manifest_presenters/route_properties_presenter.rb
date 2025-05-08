module VCAP::CloudController
  module Presenters
    module V3
      module AppManifestPresenters
        class RoutePropertiesPresenter
          def to_hash(route_mappings:, app:, **_)
            route_hashes = route_mappings.map do |route_mapping|
              route_hash = {
                route: route_mapping.route.uri,
                protocol: route_mapping.protocol
              }

              if route_mapping.route.options
                route_hash[:options] = {}
                route_hash[:options][:loadbalancing] = route_mapping.route.options[:loadbalancing] if route_mapping.route.options[:loadbalancing]
              end

              route_hash
            end

            { routes: alphabetize(route_hashes).presence }
          end

          private

          def alphabetize(array)
            array.sort_by { |obj| obj[:route].downcase }
          end
        end
      end
    end
  end
end
