module CloudController
  module Presenters
    module V2
      class ServiceInstanceSharedFromPresenter
        def to_hash(space)
          {
            'space_guid' => space.guid,
            'space_name' => space.name,
            'organization_name' => space.organization.name
          }
        end
      end
    end
  end
end
