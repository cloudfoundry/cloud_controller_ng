require 'httpclient'
require 'cloud_controller/opi/base_client'
require 'cloud_controller/diego/task_completion_callback_generator'
require 'cloud_controller/diego/task_environment_variable_collector'

module OPI
  class TaskClient < BaseClient
    def initialize(config, environment_collector)
      super(config)
      @environment_collector = environment_collector
    end

    def desire_task(task, domain)
      task_request = to_request(task)
      payload = MultiJson.dump(task_request)
      response = client.post("/tasks/#{task.guid}", body: payload)
      if response.status_code != 202
        response_json = OPI.recursive_ostruct(JSON.parse(response.body))
        logger.info('tasks.response', task_guid: task.guid, error: response_json.message)
        raise CloudController::Errors::ApiError.new_from_details('RunnerError', response_json.message)
      end
    end

    def fetch_task(_)
      Diego::Bbs::Models::Task.new
    end

    def fetch_tasks
      []
    end

    def cancel_task(_); end

    def bump_freshness; end

    private

    def to_request(task)
      task_completion_callback_generator = VCAP::CloudController::Diego::TaskCompletionCallbackGenerator.new(@config)
      {
        app_guid: task.app.guid,
        app_name: task.app.name,
        org_guid: task.space.organization.guid,
        org_name: task.space.organization.name,
        space_guid: task.space.guid,
        space_name: task.space.name,
        environment: @environment_collector.for_task(task),
        completion_callback: task_completion_callback_generator.generate(task),
        lifecycle: {
          buildpack_lifecycle: {
            droplet_hash: task.droplet.droplet_hash,
            droplet_guid: task.droplet.guid,
            start_command: task.command
          }
        }
      }
    end

    def logger
      @logger ||= Steno.logger('cc.opi.task_client')
    end
  end
end
