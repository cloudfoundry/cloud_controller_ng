module VCAP::CloudController
  module Presenters
    module V3
      module AppManifestPresenters
        class RoutePropertiesPresenter
          def to_hash(route_mappings:, app:, **_)
            route_hashes = route_mappings.map do |route_mapping|
              {
                route: route_mapping.route.uri,
                protocol: route_mapping.protocol
              }
            end

            { routes: alphabetize(route_hashes).presence, }
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
