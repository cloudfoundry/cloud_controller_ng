FactoryBot.define do
  factory :organization_billing_manager, class: 'VCAP::CloudController::OrganizationBillingManager' do
    guid { generate(:guid) }
    association :user
    association :organization
  end
end
