module VCAP::CloudController
  class ServicePlanLabelModel < Sequel::Model(:service_plan_labels)
    many_to_one :service_plan,
      class: 'VCAP::CloudController::ServicePlan',
      primary_key: :guid,
      key: :resource_guid,
      without_guid_generation: true
  end
end
