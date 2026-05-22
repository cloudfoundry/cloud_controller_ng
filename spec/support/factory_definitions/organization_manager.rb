FactoryBot.define do
  factory :organization_manager, class: 'VCAP::CloudController::OrganizationManager' do
    guid { generate(:guid) }
    association :user
    association :organization
  end
end
