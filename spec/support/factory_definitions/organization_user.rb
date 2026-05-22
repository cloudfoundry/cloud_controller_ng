FactoryBot.define do
  factory :organization_user, class: 'VCAP::CloudController::OrganizationUser' do
    guid { generate(:guid) }
    association :user
    association :organization
  end
end
