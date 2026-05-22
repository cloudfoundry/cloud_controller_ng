FactoryBot.define do
  factory :deployment_label_model, class: 'VCAP::CloudController::DeploymentLabelModel' do
    guid { generate(:guid) }
  end
end
