FactoryBot.define do
  factory :event, class: 'VCAP::CloudController::Event' do
    guid              { generate(:guid) }
    timestamp         { Time.now.utc }
    type              { generate(:name) }
    actor             { generate(:guid) }
    actor_type        { generate(:name) }
    actor_name        { generate(:name) }
    actee             { generate(:guid) }
    actee_type        { generate(:name) }
    actee_name        { generate(:name) }
    organization_guid { generate(:guid) }
    metadata          { {} }
  end
end
