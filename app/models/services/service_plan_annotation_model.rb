module VCAP::CloudController
  class ServicePlanAnnotationModel < Sequel::Model(:service_plan_annotations)
    many_to_one :service_plan,
                class: 'VCAP::CloudController::ServicePlan',
                primary_key: :guid,
                key: :resource_guid,
                without_guid_generation: true

    def_column_alias(:key_name, :key)
  end
end
