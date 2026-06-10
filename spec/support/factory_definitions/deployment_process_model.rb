FactoryBot.define do
  factory :deployment_process_model, class: 'VCAP::CloudController::DeploymentProcessModel' do
    association :deployment, factory: :deployment_model
    process_guid { generate(:guid) }
    process_type { VCAP::CloudController::ProcessTypes::WEB }
  end
end
