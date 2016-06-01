module CloudController
  module Presenters
    module V2
      class PrivateDomainPresenter < BasePresenter
        extend PresenterProvider

        present_for_class 'VCAP::CloudController::PrivateDomain'

        def entity_hash(controller, domain, opts, depth, parents, orphans=nil)
          entity = {
            'name' => domain.name,
            'owning_organization_guid' => domain.owning_organization_guid
          }

          entity.merge!(RelationsPresenter.new.to_hash(controller, domain, opts, depth, parents, orphans))
        end

        private

        def metadata_hash(domain, _controller)
          {
            'guid'       => domain.guid,
            'url'        => "/v2/private_domains/#{domain.guid}",
            'created_at' => domain.created_at,
            'updated_at' => domain.updated_at
          }
        end
      end
    end
  end
end
