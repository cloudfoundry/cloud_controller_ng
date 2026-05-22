FactoryBot.define do
  factory :service_offering_label_model, class: 'VCAP::CloudController::ServiceOfferingLabelModel' do
    guid { generate(:guid) }
  end
end
