FactoryBot.define do
  factory :service_offering_annotation_model, class: 'VCAP::CloudController::ServiceOfferingAnnotationModel' do
    guid { generate(:guid) }
  end
end
