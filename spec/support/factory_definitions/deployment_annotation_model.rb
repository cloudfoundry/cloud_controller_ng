FactoryBot.define do
  factory :deployment_annotation_model, class: 'VCAP::CloudController::DeploymentAnnotationModel' do
    guid { generate(:guid) }
  end
end
