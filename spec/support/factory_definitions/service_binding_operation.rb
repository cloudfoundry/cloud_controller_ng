FactoryBot.define do
  factory :service_binding_operation, class: 'VCAP::CloudController::ServiceBindingOperation' do
    type        { 'create' }
    state       { 'succeeded' }
    description { 'description goes here' }
    updated_at  { Time.now.utc }
  end
end
