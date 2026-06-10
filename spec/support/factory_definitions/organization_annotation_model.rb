FactoryBot.define do
  factory :organization_annotation_model, class: 'VCAP::CloudController::OrganizationAnnotationModel' do
    guid { generate(:guid) }
  end
end
