module VCAP::CloudController
  class OrgLabelModel < Sequel::Model(:org_labels)
    RESOURCE_GUID_COLUMN = :org_guid

    many_to_one :org,
                class: 'VCAP::CloudController::Organization',
                primary_key: :guid,
                key: :org_guid,
                without_guid_generation: true
  end
end
