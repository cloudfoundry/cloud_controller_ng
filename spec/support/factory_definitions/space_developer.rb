FactoryBot.define do
  factory :space_developer, class: 'VCAP::CloudController::SpaceDeveloper' do
    guid { generate(:guid) }
    association :user
    association :space
  end
end
