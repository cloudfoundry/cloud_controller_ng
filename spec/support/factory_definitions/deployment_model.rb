FactoryBot.define do
  factory :deployment_model, class: 'VCAP::CloudController::DeploymentModel' do
    state { VCAP::CloudController::DeploymentModel::DEPLOYING_STATE }
    status_value { VCAP::CloudController::DeploymentModel::ACTIVE_STATUS_VALUE }
    status_reason { VCAP::CloudController::DeploymentModel::DEPLOYING_STATUS_REASON }
    association :app, factory: :app_model
    original_web_process_instance_count { 1 }
    strategy { 'rolling' }

    after(:build) do |deployment|
      deployment.droplet ||= create(:droplet_model, app: deployment.app)
      deployment.deploying_web_process ||= create(:process_model, app: deployment.app, type: "web-deployment-#{SecureRandom.uuid}")
    end
  end
end
