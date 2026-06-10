FactoryBot.define do
  factory :organization_auditor, class: 'VCAP::CloudController::OrganizationAuditor' do
    guid { generate(:guid) }
    association :user
    association :organization
  end
end
