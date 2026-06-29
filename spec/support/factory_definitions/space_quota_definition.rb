FactoryBot.define do
  factory :space_quota_definition, class: 'VCAP::CloudController::SpaceQuotaDefinition' do
    name                       { generate(:name) }
    non_basic_services_allowed { true }
    total_services             { 60 }
    total_service_keys         { 600 }
    total_routes               { 1_000 }
    memory_limit               { 20_480 }
    association :organization
  end
end
