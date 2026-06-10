FactoryBot.define do
  factory :buildpack, class: 'VCAP::CloudController::Buildpack' do
    name { generate(:name) }
    stack { VCAP::CloudController::Stack.default.name }
    key { generate(:guid) }
    position { VCAP::CloudController::Buildpack.count + 1 }
    enabled { true }
    filename { generate(:name) }
    locked { false }

    trait :nil_stack do
      stack { nil }
    end
  end
end
