require 'queries/app_fetcher'
require 'actions/task_create'
require 'messages/task_create_message'
require 'presenters/v3/task_presenter'
require 'controllers/v3/mixins/app_subresource'

class AppsTasksController < ApplicationController
  include AppSubresource

  def create
    FeatureFlag.raise_unless_enabled!('task_creation')
    message = TaskCreateMessage.new(params[:body])
    unprocessable!(message.errors.full_messages) unless message.valid?

    app_guid = params[:guid]
    app = AppModel.where(guid: app_guid).eager(:space, space: :organization).first

    app_not_found! unless app && can_read?(app.space.guid, app.space.organization.guid)
    unauthorized! unless can_create?(app.space.guid)

    task = TaskCreate.new.create(app, message)
    render status: :accepted, json: TaskPresenter.new.present_json(task)
  rescue TaskCreate::InvalidTask, TaskCreate::TaskCreateError => e
    unprocessable!(e)
  end

  def show
    query_options = { guid: params[:task_guid] }
    if params[:app_guid].present?
      query_options[:app_id] = AppModel.select(:id).where(guid: params[:app_guid])
    end
    task = TaskModel.where(query_options).eager(:space, space: :organization).first

    task_not_found! unless task && can_read?(task.space.guid, task.space.organization.guid)
    render status: :ok, json: TaskPresenter.new.present_json(task)
  end

  private

  def task_not_found!
    resource_not_found!(:task)
  end

  def can_create?(space_guid)
    roles.admin? || membership.has_any_roles?([Membership::SPACE_DEVELOPER], space_guid)
  end
end
