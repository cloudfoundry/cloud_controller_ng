FactoryBot.define do
  factory :space_auditor, class: 'VCAP::CloudController::SpaceAuditor' do
    guid { generate(:guid) }
    association :user
    association :space
  end
end
