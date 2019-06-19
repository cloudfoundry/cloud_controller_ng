module VCAP::CloudController
  class OrganizationAnnotationModel < Sequel::Model(:organization_annotations)
    many_to_one :organization,
                class: 'VCAP::CloudController::Organization',
                primary_key: :guid,
                key: :resource_guid,
                without_guid_generation: true

    def_column_alias(:key_name, :key)
  end
end
