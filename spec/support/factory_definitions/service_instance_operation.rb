FactoryBot.define do
  factory :service_instance_operation, class: 'VCAP::CloudController::ServiceInstanceOperation' do
    type        { 'create' }
    state       { 'succeeded' }
    description { 'description goes here' }
    updated_at  { Time.now.utc }
  end
end
