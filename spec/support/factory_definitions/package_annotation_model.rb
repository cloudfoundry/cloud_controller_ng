FactoryBot.define do
  factory :package_annotation_model, class: 'VCAP::CloudController::PackageAnnotationModel' do
    guid { generate(:guid) }
  end
end
