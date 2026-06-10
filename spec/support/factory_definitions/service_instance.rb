FactoryBot.define do
  factory :service_instance, class: 'VCAP::CloudController::ServiceInstance' do
    name        { generate(:name) }
    credentials { generate(:service_credentials) }
    association :space
  end
end
