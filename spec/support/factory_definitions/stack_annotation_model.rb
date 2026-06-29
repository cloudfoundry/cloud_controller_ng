FactoryBot.define do
  factory :stack_annotation_model, class: 'VCAP::CloudController::StackAnnotationModel' do
    guid { generate(:guid) }
  end
end
