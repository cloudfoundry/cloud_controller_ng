FactoryBot.define do
  factory :process_annotation_model, class: 'VCAP::CloudController::ProcessAnnotationModel' do
    guid { generate(:guid) }
  end
end
