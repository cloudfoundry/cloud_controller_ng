FactoryBot.define do
  factory :space, class: 'VCAP::CloudController::Space' do
    name { generate(:name) }
    association :organization

    trait :with_service_account_prefix do
      organization { association(:organization, service_account_prefix: "workload-#{generate(:name)}") }
    end
  end
end
