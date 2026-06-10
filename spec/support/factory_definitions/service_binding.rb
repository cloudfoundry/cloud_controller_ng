FactoryBot.define do
  factory :service_binding, class: 'VCAP::CloudController::ServiceBinding' do
    credentials { generate(:service_credentials) }
    association :service_instance, factory: :managed_service_instance
    syslog_drain_url { nil }
    type             { 'app' }
    name             { nil }
    guid             { generate(:guid) }
    app              { create(:app_model, space: service_instance.space) } # rubocop:disable FactoryBot/FactoryAssociationWithStrategy
  end
end
