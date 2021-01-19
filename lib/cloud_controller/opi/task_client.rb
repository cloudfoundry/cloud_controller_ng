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

    def fetch_task(guid)
      resp = client.get("/tasks/#{guid}")

      return if resp.status_code == 404

      if resp.status_code != 200
        raise CloudController::Errors::ApiError.new_from_details('TaskError', "response status code: #{resp.status_code}")
      end

      task = JSON.parse(resp.body)
      task[:task_guid] = task.delete('guid')
      OPI.recursive_ostruct(task)
    end

    def fetch_tasks
      resp = client.get('/tasks')

      if resp.status_code != 200
        raise CloudController::Errors::ApiError.new_from_details('TaskError', "response status code: #{resp.status_code}")
      end

      tasks = JSON.parse(resp.body)
      tasks.each do |task|
        task['task_guid'] = task.delete('guid')
      end

      tasks.map { |t| OPI.recursive_ostruct(t) }
    end

    def cancel_task(guid)
      response = client.delete("/tasks/#{guid}")
      if response.status_code > 400
        logger.info('tasks.delete.response_code', task_guid: guid, status_code: response.status_code)

        if response.status_code != 404
          response_json = OPI.recursive_ostruct(JSON.parse(response.body))
          raise CloudController::Errors::ApiError.new_from_details('TaskError', response_json.message)
        end
      end
    end

    def bump_freshness; end

    private

    def add_lifecycle(task)
      case task.droplet.lifecycle_type
      when VCAP::CloudController::Lifecycles::BUILDPACK
        {
          buildpack_lifecycle: {
            droplet_hash: task.droplet.droplet_hash,
            droplet_guid: task.droplet.guid,
            start_command: task.command
          }
        }
      when VCAP::CloudController::Lifecycles::DOCKER
        command = if task.command.present?
                    ['/bin/sh', '-c', task.command]
                  else
                    []
                  end
        {
          docker_lifecycle: {
            image: task.droplet.docker_receipt_image,
            command: command,
            registry_username: task.droplet.docker_receipt_username,
            registry_password: task.droplet.docker_receipt_password
          }
        }
      when VCAP::CloudController::Lifecycles::KPACK
        command = if task.command.present?
                    [OPI::Client::KpackLifecycle::CNB_LAUNCHER_PATH, task.command]
                  else
                    []
                  end
        {
          docker_lifecycle: {
            image: task.droplet.docker_receipt_image,
            command: command
          }
        }
      end
    end

    def to_request(task)
      task_completion_callback_generator = VCAP::CloudController::Diego::TaskCompletionCallbackGenerator.new(@config)
      {
        name: task.name,
        app_guid: task.app.guid,
        app_name: task.app.name,
        org_guid: task.space.organization.guid,
        org_name: task.space.organization.name,
        space_guid: task.space.guid,
        space_name: task.space.name,
        environment: @environment_collector.for_task(task),
        completion_callback: task_completion_callback_generator.generate(task),
        lifecycle: add_lifecycle(task)
      }
    end

    def logger
      @logger ||= Steno.logger('cc.opi.task_client')
    end
  end
end
