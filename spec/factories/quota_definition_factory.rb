require 'models/runtime/quota_definition'

FactoryBot.define do
  factory(:quota_definition, class: VCAP::CloudController::QuotaDefinition) do
    name
    non_basic_services_allowed { true }
    total_reserved_route_ports { 5 }
    total_services { 60 }
    total_routes { 1_000 }
    memory_limit { 20_480 } # 20 GB
  end
end
