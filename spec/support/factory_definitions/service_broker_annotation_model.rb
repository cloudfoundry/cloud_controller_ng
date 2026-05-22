FactoryBot.define do
  factory :service_broker_annotation_model, class: 'VCAP::CloudController::ServiceBrokerAnnotationModel' do
    guid { generate(:guid) }
  end
end
