FactoryBot.define do
  factory :route_binding_operation, class: 'VCAP::CloudController::RouteBindingOperation' do
    type        { 'create' }
    state       { 'succeeded' }
    description { 'description goes here' }
    updated_at  { Time.now.utc }
  end
end
