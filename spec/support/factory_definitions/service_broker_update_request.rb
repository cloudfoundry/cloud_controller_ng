FactoryBot.define do
  factory :service_broker_update_request, class: 'VCAP::CloudController::ServiceBrokerUpdateRequest' do
    name           { generate(:name) }
    broker_url     { generate(:url) }
    authentication { '{"credentials":{"username":"new-admin","password":"welcome"}}' }
    service_broker_id { create(:service_broker).id }
  end
end
