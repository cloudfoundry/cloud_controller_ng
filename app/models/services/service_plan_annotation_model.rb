module VCAP::CloudController
  class ServicePlanAnnotationModel < Sequel::Model(:service_plan_annotations_migration_view)
    set_primary_key :id
    many_to_one :service_plan,
                class: 'VCAP::CloudController::ServicePlan',
                primary_key: :guid,
                key: :resource_guid,
                without_guid_generation: true
    include MetadataModelMixin
  end
end
