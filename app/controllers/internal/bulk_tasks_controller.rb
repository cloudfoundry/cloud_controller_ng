require 'sinatra'
require 'controllers/base/base_controller'
require 'cloud_controller/internal_api'
require 'cloud_controller/diego/task_completion_callback_generator'

module VCAP::CloudController
  class BulkTasksController < RestController::BaseController
    # Endpoint does its own (non-standard) auth
    allow_unauthenticated_access

    def initialize(*)
      super
      auth = Rack::Auth::Basic::Request.new(env)
      unless auth.provided? && auth.basic? && auth.credentials == InternalApi.credentials
        raise CloudController::Errors::NotAuthenticated
      end
    end

    get '/internal/v3/bulk/task_states', :bulk_task_states
    def bulk_task_states
      batch_size = Integer(params.fetch('batch_size'))
      bulk_token = MultiJson.load(params.fetch('token'))
      last_id = Integer(bulk_token['id'] || 0)

      tasks = TaskModel.where{ Sequel[:tasks][:id] > last_id }.order(:id).limit(batch_size).all
      id_for_next_token = tasks.empty? ? nil : tasks.last.id
      presented_task_states = task_states(tasks)

      MultiJson.dump(task_states: presented_task_states, token: { id: id_for_next_token })
    rescue IndexError => e
      raise ApiError.new_from_details('BadQueryParameter', e.message)
    end

    private

    def task_states(tasks)
      callback_generator = Diego::TaskCompletionCallbackGenerator.new
      tasks.map do |task|
        {
          task_guid: task.guid,
          state: task.state,
          completion_callback: callback_generator.generate(task)
        }
      end
    end
  end
end
