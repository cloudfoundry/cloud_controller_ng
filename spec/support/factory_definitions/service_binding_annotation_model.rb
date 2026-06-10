FactoryBot.define do
  factory :service_binding_annotation_model, class: 'VCAP::CloudController::ServiceBindingAnnotationModel' do
    guid { generate(:guid) }
  end
end
