FactoryBot.define do
  factory :service_key_annotation_model, class: 'VCAP::CloudController::ServiceKeyAnnotationModel' do
    guid { generate(:guid) }
  end
end
