module VCAP::CloudController
  class OrganizationLabelModel < Sequel::Model(:organization_labels)
    many_to_one :organization,
                class: 'VCAP::CloudController::Organization',
                primary_key: :guid,
                key: :resource_guid,
                without_guid_generation: true
  end
end
