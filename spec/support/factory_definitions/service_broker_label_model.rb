FactoryBot.define do
  factory :service_broker_label_model, class: 'VCAP::CloudController::ServiceBrokerLabelModel' do
    guid { generate(:guid) }
  end
end
