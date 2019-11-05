require 'httpclient'
require 'cloud_controller/opi/base_client'

module OPI
  class TaskClient < BaseClient
    def desire_task(task_guid, task_definition, domain)
      nil
    end

    def fetch_task(_)
      Diego::Bbs::Models::Task.new
    end

    def fetch_tasks
      []
    end

    def cancel_task(_); end

    def bump_freshness; end
  end
end
