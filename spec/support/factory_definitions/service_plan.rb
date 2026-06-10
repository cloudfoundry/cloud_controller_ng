FactoryBot.define do
  factory :service_plan, class: 'VCAP::CloudController::ServicePlan' do
    name              { generate(:name) }
    free              { false }
    description       { generate(:description) }
    association :service
    unique_id         { SecureRandom.uuid }
    active            { true }
    maintenance_info  { nil }

    trait :routing do
      association :service, factory: %i[service routing]
    end

    trait :volume_mount do
      association :service, factory: %i[service volume_mount]
    end

    trait :v2 do
    end
  end
end
