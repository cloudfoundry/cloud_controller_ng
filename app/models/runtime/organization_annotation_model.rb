module VCAP::CloudController
  class OrganizationAnnotationModel < Sequel::Model(:organization_annotations)
    set_primary_key :id
    many_to_one :organization,
                class: 'VCAP::CloudController::Organization',
                primary_key: :guid,
                key: :resource_guid,
                without_guid_generation: true

    include MetadataModelMixin
  end
end
