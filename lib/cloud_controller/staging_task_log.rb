require 'steno'

module VCAP::CloudController
  class StagingTaskLog
    class << self

      def key_for_id(app_id)
        "staging_task_log:#{app_id}"
      end

      def fetch(app_id, redis)
        key = key_for_id(app_id)

        logger = Steno.logger('vcap.stager.task_result.fetch')
        logger.debug("Fetching result for key '#{key}' from redis")

        res = redis.get(key)
        res ? StagingTaskLog.new(app_id, res, redis) : nil
      end
    end

    attr_reader :app_id, :task_log

    def initialize(app_id, task_log, redis)
      @app_id   = app_id
      @task_log = task_log
      @redis = redis
    end

    def save
      key = self.class.key_for_id(@app_id)
      @redis.set(key, @task_log)
    end
  end
end
