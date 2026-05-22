FactoryBot.define do
  factory :organization, class: 'VCAP::CloudController::Organization' do
    name { generate(:name) }
    association :quota_definition
    status { 'active' }
  end
end
