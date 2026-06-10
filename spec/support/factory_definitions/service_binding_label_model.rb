FactoryBot.define do
  factory :service_binding_label_model, class: 'VCAP::CloudController::ServiceBindingLabelModel' do
    guid { generate(:guid) }
  end
end
