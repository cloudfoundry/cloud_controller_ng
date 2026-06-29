FactoryBot.define do
  factory :service_usage_event, class: 'VCAP::CloudController::ServiceUsageEvent' do
    state                 { 'CREATED' }
    org_guid              { generate(:guid) }
    space_guid            { generate(:guid) }
    space_name            { generate(:name) }
    service_instance_guid { generate(:guid) }
    service_instance_name { generate(:name) }
    service_instance_type { generate(:type) }
    service_plan_guid     { generate(:guid) }
    service_plan_name     { generate(:name) }
    service_guid          { generate(:guid) }
    service_label         { generate(:label) }
  end
end
