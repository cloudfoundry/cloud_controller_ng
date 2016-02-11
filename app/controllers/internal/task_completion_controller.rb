require 'sinatra'
require 'controllers/base/base_controller'
require 'cloud_controller/internal_api'
require 'cloud_controller/diego/task_completion_handler'

module VCAP::CloudController
  class TasksCompletionController < RestController::BaseController
    allow_unauthenticated_access

    def initialize(*)
      super
      auth = Rack::Auth::Basic::Request.new(env)
      unless auth.provided? && auth.basic? && auth.credentials == InternalApi.credentials
        raise Errors::ApiError.new_from_details('NotAuthenticated')
      end
    end

    post '/internal/v3/tasks/:task_guid/completed', :complete_task
    def complete_task(task_guid)
      task_response = read_body
      task = TaskModel.find(guid: task_guid)
      raise Errors::ApiError.new_from_details('NotFound') unless task
      raise Errors::ApiError.new_from_details('InvalidRequest') if task_guid != task_response[:task_guid]
      raise Errors::ApiError.new_from_details('InvalidRequest') if [TaskModel::SUCCEEDED_STATE, TaskModel::FAILED_STATE].include? task.state

      Diego::TaskCompletionHandler.new.complete_task(task, task_response)

      [200, '{}']
    end

    private

    def read_body
      task_response = {}
      begin
        payload = body.read
        task_response = MultiJson.load(payload, symbolize_keys: true)
      rescue MultiJson::ParseError => pe
        logger.error('diego.task.parse-error', payload: payload, error: pe.to_s)
        raise Errors::ApiError.new_from_details('MessageParseError', payload)
      end

      task_response
    end
  end
end
