FactoryBot.define do
  factory :space_manager, class: 'VCAP::CloudController::SpaceManager' do
    guid { generate(:guid) }
    association :user
    association :space
  end
end
