module VCAP::CloudController
  module Jobs
    module Runtime
      class PruneCompletedBuilds < VCAP::CloudController::Jobs::CCJob
        attr_accessor :max_retained_builds_per_app

        def initialize(max_retained_builds_per_app)
          @max_retained_builds_per_app = max_retained_builds_per_app
        end

        def perform
          logger = Steno.logger('cc.background')
          logger.info('Cleaning up old builds')

          guids_for_apps_with_builds = BuildModel.
                                       distinct(:app_guid).
                                       map(&:app_guid)

          guids_for_apps_with_builds.each do |app_guid|
            builds_dataset = BuildModel.where(app_guid: app_guid)

            builds_to_keep = builds_dataset.
                             order(Sequel.desc(:created_at)).
                             limit(max_retained_builds_per_app).
                             select(:id)

            delete_count = builds_dataset.
                           where(state: BuildModel::FINAL_STATES).
                           exclude(id: builds_to_keep).
                           destroy

            logger.info("Cleaned up #{delete_count} BuildModel rows for app #{app_guid}")
          end
        end

        def job_name_in_configuration
          :prune_completed_builds
        end

        def max_attempts
          1
        end
      end
    end
  end
end
