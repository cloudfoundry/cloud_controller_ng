FactoryBot.define do
  factory :task_annotation_model, class: 'VCAP::CloudController::TaskAnnotationModel' do
    guid { generate(:guid) }
  end
end
