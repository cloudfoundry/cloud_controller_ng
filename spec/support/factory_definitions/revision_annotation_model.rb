FactoryBot.define do
  factory :revision_annotation_model, class: 'VCAP::CloudController::RevisionAnnotationModel' do
    guid { generate(:guid) }
  end
end
