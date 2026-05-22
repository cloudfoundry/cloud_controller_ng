FactoryBot.define do
  factory :app_event, class: 'VCAP::CloudController::AppEvent' do
    association :app, factory: :process_model
    instance_guid    { generate(:guid) }
    instance_index   { generate(:instance_index) }
    exit_status      { Random.rand(256) }
    exit_description { generate(:description) }
    timestamp        { Time.now.utc }
  end
end
