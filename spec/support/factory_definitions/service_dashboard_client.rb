FactoryBot.define do
  factory :service_dashboard_client, class: 'VCAP::CloudController::ServiceDashboardClient' do
    uaa_id { generate(:name) }
    association :service_broker
  end
end
