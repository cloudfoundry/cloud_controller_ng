FactoryBot.define do
  factory :space_annotation_model, class: 'VCAP::CloudController::SpaceAnnotationModel' do
    guid { generate(:guid) }
  end
end
