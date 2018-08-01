module VCAP::CloudController
  module Diego
    class TasksSync
      BATCH_SIZE = 500

      class Error < StandardError
      end
      class BBSFetchError < Error
      end

      def initialize(config)
        @config = config
        @workpool = WorkPool.new(50)
      end

      def sync
        diego_tasks = bbs_task_client.fetch_tasks.index_by(&:task_guid)

        batched_tasks do |tasks|
          tasks_to_fail = []

          tasks.each do |task|
            diego_task = diego_tasks.delete(task.guid)
            next unless [TaskModel::RUNNING_STATE, TaskModel::CANCELING_STATE].include? task.state

            if diego_task.nil?
              tasks_to_fail << task.guid
              logger.info('missing-diego-task', task_guid: task.guid)
            elsif task.state == TaskModel::CANCELING_STATE
              @workpool.submit(task.guid) do |guid|
                bbs_task_client.cancel_task(guid)
                logger.info('canceled-cc-task', task_guid: guid)
              end
            end
          end

          TaskModel.where(guid: tasks_to_fail).update(state: TaskModel::FAILED_STATE, failure_reason: BULKER_TASK_FAILURE)
        end

        diego_tasks.keys.each do |task_guid|
          @workpool.submit(task_guid) do |guid|
            bbs_task_client.cancel_task(guid)
            logger.info('missing-cc-task', task_guid: guid)
          end
        end

        @workpool.drain

        bbs_task_client.bump_freshness
      rescue CloudController::Errors::ApiError => e
        logger.info('sync-failed', error: e)
        raise BBSFetchError.new(e.message)
      end

      private

      def batched_tasks
        last_id = 0
        loop do
          tasks = TaskModel.where('tasks.id > ?', last_id).order(:id).limit(BATCH_SIZE)
          yield tasks
          return if tasks.count < BATCH_SIZE
          last_id = tasks.last[0]
        end
      end

      def bbs_task_client
        CloudController::DependencyLocator.instance.bbs_task_client
      end

      def logger
        @logger ||= Steno.logger('cc.diego.sync.tasks')
      end
    end
  end
end
