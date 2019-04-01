module VCAP::CloudController
  module Jobs
    module Runtime
      class PruneCompletedDeployments < VCAP::CloudController::Jobs::CCJob
        attr_accessor :max_retained_deployments_per_app

        def initialize(max_retained_deployments_per_app)
          @max_retained_deployments_per_app = max_retained_deployments_per_app
        end

        def perform
          logger = Steno.logger('cc.background')
          logger.info('Cleaning up old deployments')

          guids_for_apps_with_deployments = DeploymentModel.
                                            distinct(:app_guid).
                                            map(&:app_guid)

          guids_for_apps_with_deployments.each do |app_guid|
            deployments_dataset = DeploymentModel.where(app_guid: app_guid)

            deployments_to_keep = deployments_dataset.
                                  order(Sequel.desc(:created_at)).
                                  limit(max_retained_deployments_per_app).
                                  select(:id)

            deployments_to_delete = deployments_dataset.
                                    exclude(state: [DeploymentModel::DEPLOYING_STATE, DeploymentModel::CANCELING_STATE]).
                                    exclude(id: deployments_to_keep)

            DeploymentDelete.delete(deployments_to_delete)

            logger.info("Cleaned up #{deployments_to_delete.count} DeploymentModel rows for app #{app_guid}")
          end
        end

        def job_name_in_configuration
          :prune_completed_deployments
        end

        def max_attempts
          1
        end
      end
    end
  end
end
