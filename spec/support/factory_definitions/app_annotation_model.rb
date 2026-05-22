FactoryBot.define do
  factory :app_annotation_model, class: 'VCAP::CloudController::AppAnnotationModel' do
    guid { generate(:guid) }
  end
end
