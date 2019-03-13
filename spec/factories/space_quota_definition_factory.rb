require 'models/runtime/space_quota_definition'

FactoryBot.define do
  factory :space_quota_definition, class: VCAP::CloudController::SpaceQuotaDefinition do
    name
    organization

    non_basic_services_allowed { true }
    total_services { 60 }
    total_service_keys { 600 }
    total_routes { 1_000 }
    memory_limit { 20_480 } # 20 GB
  end
end
