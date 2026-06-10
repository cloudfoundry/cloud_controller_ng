FactoryBot.define do
  factory :managed_service_instance, class: 'VCAP::CloudController::ManagedServiceInstance' do
    is_gateway_service { true }
    name               { generate(:name) }
    credentials        { generate(:service_credentials) }
    association :space
    association :service_plan
    gateway_name       { generate(:guid) }
    maintenance_info   { nil }

    trait :routing do
      association :service_plan, factory: %i[service_plan routing]
    end

    trait :volume_mount do
      association :service_plan, factory: %i[service_plan volume_mount]
    end

    trait :all_fields do
      gateway_data      { 'some data' }
      dashboard_url     { generate(:url) }
      syslog_drain_url  { generate(:url) }
      tags              { %w[a-tag another-tag] }
      route_service_url { generate(:url) }
      maintenance_info  { 'maintenance info' }
    end

    trait :v2 do
    end
  end
end
