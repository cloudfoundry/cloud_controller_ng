FactoryBot.define do
  factory :buildpack_annotation_model, class: 'VCAP::CloudController::BuildpackAnnotationModel' do
    guid { generate(:guid) }
  end
end
