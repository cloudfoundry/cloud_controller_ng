FactoryBot.define do
  factory :user_provided_service_instance, class: 'VCAP::CloudController::UserProvidedServiceInstance' do
    name               { generate(:name) }
    credentials        { generate(:service_credentials) }
    syslog_drain_url   { generate(:url) }
    association :space
    is_gateway_service { false }

    trait :routing do
      route_service_url { generate(:url) }
    end
  end
end
