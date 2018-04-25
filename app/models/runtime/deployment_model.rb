module VCAP::CloudController
  class DeploymentModel < Sequel::Model(:deployments)
    DEPLOYING_STATE = 'DEPLOYING'.freeze

    many_to_one :app, class: 'VCAP::CloudController::AppModel',
                      primary_key: :guid,
                      key: :app_guid,
                      without_guid_generation: true
  end
end
