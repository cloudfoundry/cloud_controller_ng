module VCAP::CloudController
  module Jobs
    module Runtime
      class PruneCompletedTasks < VCAP::CloudController::Jobs::CCJob
        attr_accessor :cutoff_age_in_days

        def initialize(cutoff_age_in_days)
          @cutoff_age_in_days = cutoff_age_in_days
        end

        def perform
          logger = Steno.logger('cc.background')
          logger.info('Cleaning up old TaskModel rows')

          tasks_to_delete = TaskModel.where(state: prunable_states).where('updated_at < ?', cutoff_age)
          deleted_count   = tasks_to_delete.destroy

          logger.info("Cleaned up #{deleted_count} TaskModel rows")
        end

        def job_name_in_configuration
          :prune_completed_tasks
        end

        def max_attempts
          1
        end

        def cutoff_age
          Time.now.utc - cutoff_age_in_days.days
        end

        def prunable_states
          [TaskModel::FAILED_STATE, TaskModel::SUCCEEDED_STATE]
        end
      end
    end
  end
end
