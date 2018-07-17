module CloudController
  module Presenters
    module V2
      class SpacePresenter < BasePresenter
        extend PresenterProvider

        present_for_class 'VCAP::CloudController::Space'

        def entity_hash(controller, space, opts, depth, parents, orphans=nil)
          entity = {
            'name'                        => space.name,
            'organization_guid'           => space.organization.guid,
            'space_quota_definition_guid' => space.space_quota_definition_guid,
            'isolation_segment_guid'      => space.isolation_segment_guid,
            'allow_ssh'                   => space.allow_ssh,
          }

          entity['isolation_segment_url'] = "/v3/isolation_segments/#{space.isolation_segment_guid}" unless space.isolation_segment_guid.nil?

          entity.merge!(RelationsPresenter.new.to_hash(controller, space, opts, depth, parents, orphans))

          entity
        end
      end
    end
  end
end
