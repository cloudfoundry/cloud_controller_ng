FactoryBot.define do
  factory :service, class: 'VCAP::CloudController::Service' do
    label                 { generate(:label) }
    unique_id             { SecureRandom.uuid }
    bindable              { true }
    active                { true }
    association :service_broker
    description           { generate(:description) }
    extra                 { '{"shareable": true, "documentationUrl": "https://some.url.for.docs/"}' }
    instances_retrievable { false }
    bindings_retrievable  { false }
    plan_updateable       { false }

    trait :routing do
      requires { ['route_forwarding'] }
    end

    trait :volume_mount do
      requires { ['volume_mount'] }
    end

    trait :v2 do
    end
  end
end
