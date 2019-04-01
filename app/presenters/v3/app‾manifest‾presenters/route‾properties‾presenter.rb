module VCAP::CloudController
  module Presenters
    module V3
      module AppManifestPresenters
        class RoutePropertiesPresenter
          def to_hash(routes:, **_)
            route_hashes = alphabetize(routes.map(&:uri)).map { |uri| { route: uri } }
            { routes: route_hashes.presence, }
          end

          def alphabetize(array)
            array.sort_by(&:downcase)
          end
        end
      end
    end
  end
end
