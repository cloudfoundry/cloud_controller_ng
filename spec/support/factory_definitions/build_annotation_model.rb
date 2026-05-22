FactoryBot.define do
  factory :build_annotation_model, class: 'VCAP::CloudController::BuildAnnotationModel' do
    guid { generate(:guid) }
  end
end
