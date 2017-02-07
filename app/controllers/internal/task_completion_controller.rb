require 'sinatra'
require 'controllers/base/base_controller'
require 'cloud_controller/internal_api'
require 'cloud_controller/diego/task_completion_handler'

module VCAP::CloudController
  class TasksCompletionController < RestController::BaseController
    allow_unauthenticated_access

    post '/internal/v3/tasks/:task_guid/completed', :v3_complete_task
    def v3_complete_task(task_guid)
      auth = Rack::Auth::Basic::Request.new(env)
      unless auth.provided? && auth.basic? && auth.credentials == InternalApi.credentials
        raise CloudController::Errors::NotAuthenticated
      end

      complete_task(task_guid, read_body)

      [200, '{}']
    end

    post '/internal/v4/tasks/:task_guid/completed', :v4_complete_task
    def v4_complete_task(task_guid)
      complete_task(task_guid, read_body)

      [200, '{}']
    end

    private

    def complete_task(task_guid, task_response)
      task = TaskModel.find(guid: task_guid)
      raise CloudController::Errors::NotFound.new_from_details('ResourceNotFound', "Task not found: #{task_guid}") unless task
      raise CloudController::Errors::ApiError.new_from_details('InvalidRequest') if task_guid != task_response[:task_guid]
      raise CloudController::Errors::ApiError.new_from_details('InvalidRequest') if [TaskModel::SUCCEEDED_STATE, TaskModel::FAILED_STATE].include? task.state

      Diego::TaskCompletionHandler.new.complete_task(task, task_response)
    end

    def read_body
      task_response = {}
      begin
        payload = body.read
        task_response = MultiJson.load(payload, symbolize_keys: true)
      rescue MultiJson::ParseError => pe
        logger.error('diego.task.parse-error', payload: payload, error: pe.to_s)
        raise CloudController::Errors::ApiError.new_from_details('MessageParseError', payload)
      end

      task_response
    end
  end
end
