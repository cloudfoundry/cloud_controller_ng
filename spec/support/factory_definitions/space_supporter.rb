FactoryBot.define do
  factory :space_supporter, class: 'VCAP::CloudController::SpaceSupporter' do
    guid { generate(:guid) }
    association :user
    association :space
  end
end
