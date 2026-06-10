FactoryBot.define do
  factory :service_key, class: 'VCAP::CloudController::ServiceKey' do
    credentials { generate(:service_credentials) }
    association :service_instance, factory: :managed_service_instance
    name        { generate(:name) }

    trait :credhub_reference do
      credentials { { 'credhub-ref' => generate(:name) } }
    end
  end
end
