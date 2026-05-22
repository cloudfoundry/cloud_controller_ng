FactoryBot.define do
  factory :space, class: 'VCAP::CloudController::Space' do
    name { generate(:name) }
    association :organization
  end
end
