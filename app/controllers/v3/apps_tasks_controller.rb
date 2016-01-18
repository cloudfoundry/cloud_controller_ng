require 'queries/app_fetcher'
require 'actions/task_create'
require 'messages/task_create_message'
require 'presenters/v3/task_presenter'

class AppsTasksController < ApplicationController
  def create
    FeatureFlag.raise_unless_enabled!('task_creation')
    message = TaskCreateMessage.new(params[:body])

    app_guid = params[:guid]
    app = AppModel.where(guid: app_guid).first

    task     = TaskCreate.new.create(app, message)
    render status: :accepted, json: TaskPresenter.new.present_json(task)
  rescue TaskCreate::InvalidTask => e
    unprocessable!(e)
  end
end
