module VCAP::CloudController
  module Diego
    class TasksSync
      BATCH_SIZE = 500

      class Error < StandardError
      end
      class BBSFetchError < Error
      end

      def initialize(config:)
        @config   = config
        @workpool = WorkPool.new(50, store_exceptions: true)
      end

      def sync
        logger.info('run-task-sync')
        @bump_freshness = true

        diego_tasks = bbs_task_client.fetch_tasks.index_by(&:task_guid)

        batched_cc_tasks do |cc_tasks|
          tasks_to_fail = []

          cc_tasks.each do |cc_task|
            diego_task = diego_tasks.delete(cc_task.guid)
            next unless [TaskModel::RUNNING_STATE, TaskModel::CANCELING_STATE].include? cc_task.state

            if diego_task.nil?
              tasks_to_fail << cc_task.guid if diego_task_missing?(cc_task.guid) && !task_finished_while_iterating?(cc_task.guid)
              logger.info('missing-diego-task', task_guid: cc_task.guid)
            elsif cc_task.state == TaskModel::CANCELING_STATE
              workpool.submit(cc_task.guid) do |guid|
                bbs_task_client.cancel_task(guid)
                logger.info('canceled-cc-task', task_guid: guid)
              end
            end
          end

          TaskModel.where(guid: tasks_to_fail).each do |cc_task|
            cc_task.update(state: TaskModel::FAILED_STATE, failure_reason: BULKER_TASK_FAILURE)
          end
        end

        diego_tasks.each_key do |task_guid|
          workpool.submit(task_guid) do |guid|
            bbs_task_client.cancel_task(guid)
            logger.info('missing-cc-task', task_guid: guid)
          end
        end

        workpool.drain

        process_workpool_exceptions(workpool.exceptions)
      rescue CloudController::Errors::ApiError => e
        logger.info('sync-failed', error: e.name, error_message: e.message)
        @bump_freshness = false
        raise BBSFetchError.new(e.message)
      rescue => e
        logger.info('sync-failed', error: e.class.name, error_message: e.message)
        @bump_freshness = false
        raise
      ensure
        workpool.drain
        if @bump_freshness
          bbs_task_client.bump_freshness
          logger.info('finished-task-sync')
        else
          logger.info('sync-failed')
        end
      end

      private

      attr_reader :workpool

      def process_workpool_exceptions(exceptions)
        exceptions.each do |e|
          logger.error('error-cancelling-task', error: e.class.name, error_message: e.message, error_backtrace: formatted_backtrace_from_error(e))
          @bump_freshness = false
        end
      end

      def formatted_backtrace_from_error(error)
        error.backtrace.present? ? error.backtrace.join("\n") + "\n..." : ''
      end

      def diego_task_missing?(task_guid)
        bbs_task_client.fetch_task(task_guid).nil?
      end

      def task_finished_while_iterating?(task_guid)
        cc_task = TaskModel.find(guid: task_guid)
        cc_task.state == TaskModel::FAILED_STATE || cc_task.state == TaskModel::SUCCEEDED_STATE
      end

      def batched_cc_tasks
        last_id = 0
        loop do
          tasks = TaskModel.where(
            Sequel.lit('tasks.id > ?', last_id)
          ).order(:id).limit(BATCH_SIZE).all

          yield tasks
          return if tasks.count < BATCH_SIZE

          last_id = tasks.last.id
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
