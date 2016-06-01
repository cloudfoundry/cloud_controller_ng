module CloudController
  module Presenters
    module V2
      class RoutePresenter < BasePresenter
        extend PresenterProvider

        present_for_class 'VCAP::CloudController::Route'

        def entity_hash(controller, obj, opts, depth, parents, orphans=nil)
          route = obj

          entity = {
            'host'                  => route.host,
            'path'                  => route.path,
            'domain_guid'           => route.domain_guid,
            'space_guid'            => route.space_guid,
            'service_instance_guid' => route.service_instance_guid,
            'port'                  => route.port,
          }

          entity.merge!(RelationsPresenter.new.to_hash(controller, obj, opts, depth, parents, orphans))
          correct_domain_url!(entity, route)

          entity
        end

        private

        def correct_domain_url!(entity, route)
          entity['domain_url'] = "/v2/#{domain_path_prefix(route)}/#{route.domain_guid}" if route.domain_guid
        end

        def domain_path_prefix(route)
          if route.domain.is_a?(VCAP::CloudController::SharedDomain)
            'shared_domains'
          elsif route.domain.is_a?(VCAP::CloudController::PrivateDomain)
            'private_domains'
          else
            'domains'
          end
        end
      end
    end
  end
end
