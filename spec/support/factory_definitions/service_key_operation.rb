FactoryBot.define do
  factory :service_key_operation, class: 'VCAP::CloudController::ServiceKeyOperation' do
    type        { 'create' }
    state       { 'succeeded' }
    description { 'description goes here' }
    updated_at  { Time.now.utc }
  end
end
