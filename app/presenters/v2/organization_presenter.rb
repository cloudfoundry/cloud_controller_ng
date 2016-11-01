module CloudController
  module Presenters
    module V2
      class OrganizationPresenter < BasePresenter
        extend PresenterProvider

        present_for_class 'VCAP::CloudController::Organization'

        def entity_hash(controller, org, opts, depth, parents, orphans=nil)
          entity = {
            'name' => org.name,
            'billing_enabled' => org.billing_enabled,
            'quota_definition_guid' => org.quota_definition_guid,
            'status' => org.status,
            'default_isolation_segment_guid' => org.default_isolation_segment_model ? org.default_isolation_segment_model.guid : nil
          }

          entity['isolation_segment_url'] = "/v2/organizations/#{org.guid}/isolation_segments" unless org.isolation_segment_models.empty?

          entity.merge!(RelationsPresenter.new.to_hash(controller, org, opts, depth, parents, orphans))

          entity
        end
      end
    end
  end
end
