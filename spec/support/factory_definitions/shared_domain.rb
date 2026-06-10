FactoryBot.define do
  factory :shared_domain, class: 'VCAP::CloudController::SharedDomain' do
    name { generate(:domain) }

    trait :tcp do
      router_group_guid { generate(:guid) }
    end
  end
end
