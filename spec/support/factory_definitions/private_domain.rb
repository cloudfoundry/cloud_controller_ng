FactoryBot.define do
  factory :private_domain, class: 'VCAP::CloudController::PrivateDomain' do
    name { generate(:domain) }
    association :owning_organization, factory: :organization
  end
end
