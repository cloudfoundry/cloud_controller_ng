FactoryBot.define do
  factory :user_annotation_model, class: 'VCAP::CloudController::UserAnnotationModel' do
    guid { generate(:guid) }
  end
end
