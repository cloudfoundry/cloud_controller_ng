FactoryBot.define do
  factory :service_instance_annotation_model, class: 'VCAP::CloudController::ServiceInstanceAnnotationModel' do
    guid { generate(:guid) }
  end
end
