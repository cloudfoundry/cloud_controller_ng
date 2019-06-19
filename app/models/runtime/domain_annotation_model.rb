module VCAP::CloudController
  class DomainAnnotationModel < Sequel::Model(:domain_annotations)
    many_to_one :domain,
                class: 'VCAP::CloudController::DomainModel',
                primary_key: :guid,
                key: :resource_guid,
                without_guid_generation: true

    def_column_alias(:key_name, :key)
  end
end
