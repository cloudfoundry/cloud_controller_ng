require 'queries/app_fetcher'
require 'queries/task_list_fetcher'
require 'actions/task_create'
require 'messages/task_create_message'
require 'messages/tasks_list_message'
require 'presenters/v3/task_presenter'
require 'controllers/v3/mixins/app_subresource'
require 'cloud_controller/diego/nsync_client'
require 'actions/task_cancel'

class TasksController < ApplicationController
  include AppSubresource

  def index
    app_guid = params[:app_guid]
    message = TasksListMessage.from_params(query_params)
    invalid_param!(message.errors.full_messages) unless message.valid?

    pagination_options = PaginationOptions.from_params(query_params)
    invalid_param!(pagination_options.errors.full_messages) unless pagination_options.valid?

    paginated_result = nil
    fetcher = TaskListFetcher.new

    if app_guid
      app, space, org = AppFetcher.new.fetch(app_guid)
      app_not_found! unless app && can_read?(space.guid, org.guid)
      base_url = "/v3/apps/#{app_guid}/tasks"
      paginated_result = fetcher.fetch_for_app(pagination_options: pagination_options, message: message, app_guid: app_guid)
    else
      paginated_result = if roles.admin?
                           fetcher.fetch_all(pagination_options: pagination_options, message: message)
                         else
                           fetcher.fetch_for_spaces(pagination_options: pagination_options, message: message, space_guids: readable_space_guids)
                         end
      base_url = '/v3/tasks'
    end

    render :ok, json: TaskPresenter.new.present_json_list(paginated_result, base_url, message)
  end

  def create
    FeatureFlag.raise_unless_enabled!('task_creation') unless roles.admin?
    message = TaskCreateMessage.new(params[:body])
    unprocessable!(message.errors.full_messages) unless message.valid?

    app_guid = params[:guid]
    app = AppModel.where(guid: app_guid).eager(:space, space: :organization).first
    app_not_found! unless app
    space = app.space

    app_not_found! unless can_read?(space.guid, space.organization.guid)
    unauthorized! unless can_create?(space.guid)

    if message.droplet_guid.present?
      droplet = app.droplet_dataset.where(guid: message.droplet_guid).first
      droplet_not_found! unless droplet
    end

    task = TaskCreate.new(configuration).create(app, message, current_user.guid, current_user_email, droplet: droplet)

    render status: :accepted, json: TaskPresenter.new.present_json(task)
  rescue TaskCreate::InvalidTask, TaskCreate::TaskCreateError => e
    unprocessable!(e)
  end

  def cancel
    query_options = { guid: params[:task_guid] }
    if params[:app_guid].present?
      query_options[:app_id] = AppModel.select(:id).where(guid: params[:app_guid])
    end
    task = TaskModel.where(query_options).eager(:space, space: :organization).first

    task_not_found! unless task && can_read?(task.space.guid, task.space.organization.guid)
    unauthorized! unless can_cancel?(task.space.guid)
    if task.state == TaskModel::SUCCEEDED_STATE || task.state == TaskModel::FAILED_STATE
      invalid_task_request!("Task state is #{task.state} and therefore cannot be canceled")
    end

    TaskCancel.new.cancel(task: task, user: current_user, email: current_user_email)

    render status: :accepted, json: TaskPresenter.new.present_json(task.reload)
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

  def indexing_space_guids
    unless roles.admin?
      membership.space_guids_for_roles(
        [Membership::SPACE_DEVELOPER,
         Membership::SPACE_MANAGER,
         Membership::SPACE_AUDITOR])
    end
  end

  def task_not_found!
    resource_not_found!(:task)
  end

  def droplet_not_found!
    resource_not_found!(:droplet)
  end

  def invalid_task_request!(message)
    raise VCAP::Errors::ApiError.new_from_details('InvalidTaskRequest', message)
  end

  def can_create?(space_guid)
    roles.admin? || membership.has_any_roles?([Membership::SPACE_DEVELOPER], space_guid)
  end
  alias_method :can_cancel?, :can_create?
end
