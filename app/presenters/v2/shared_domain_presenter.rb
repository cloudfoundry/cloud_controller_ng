module CloudController
  module Presenters
    module V2
      class SharedDomainPresenter < BasePresenter
        extend PresenterProvider

        present_for_class 'VCAP::CloudController::SharedDomain'

        def entity_hash(controller, domain, opts, depth, parents, orphans=nil)
          entity = {
            'name' => domain.name,
            'router_group_guid' => domain.router_group_guid,
            'router_group_type' => domain.router_group_type
          }

          entity.merge!(RelationsPresenter.new.to_hash(controller, domain, opts, depth, parents, orphans))
        end

        private

        def metadata_hash(domain, _controller)
          {
            'guid'       => domain.guid,
            'url'        => "/v2/shared_domains/#{domain.guid}",
            'created_at' => domain.created_at,
            'updated_at' => domain.updated_at
          }
        end
      end
    end
  end
end
