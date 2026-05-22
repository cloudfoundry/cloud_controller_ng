FactoryBot.define do
  factory :app_usage_event, class: 'VCAP::CloudController::AppUsageEvent' do
    state                     { 'STARTED' }
    package_state             { 'STAGED' }
    instance_count            { 1 }
    memory_in_mb_per_instance { 564 }
    app_guid       { generate(:guid) }
    app_name       { generate(:name) }
    org_guid       { generate(:guid) }
    space_guid     { generate(:guid) }
    space_name     { generate(:name) }
    buildpack_guid { generate(:guid) }
    buildpack_name { generate(:name) }
    process_type   { 'web' }
  end
end
