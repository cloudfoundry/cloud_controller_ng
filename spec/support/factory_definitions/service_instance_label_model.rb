FactoryBot.define do
  factory :service_instance_label_model, class: 'VCAP::CloudController::ServiceInstanceLabelModel' do
    guid { generate(:guid) }
  end
end
