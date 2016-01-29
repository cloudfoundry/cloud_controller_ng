require 'queries/app_fetcher'
require 'queries/task_list_fetcher'
require 'actions/task_create'
require 'messages/task_create_message'
require 'messages/tasks_list_message'
require 'presenters/v3/task_presenter'
require 'controllers/v3/mixins/app_subresource'
require 'cloud_controller/diego/nsync_client'

class TasksController < ApplicationController
  include AppSubresource

  def index
    app_guid = params[:app_guid]
    message = TasksListMessage.from_params(query_params)
    invalid_param!(message.errors.full_messages) unless message.valid?

    pagination_options = PaginationOptions.from_params(query_params)
    invalid_param!(pagination_options.errors.full_messages) unless pagination_options.valid?

    if app_guid
      app, space, org = AppFetcher.new.fetch(app_guid)
      app_not_found! unless app && can_read?(space.guid, org.guid)
      base_url = "/v3/apps/#{app_guid}/tasks"
    else
      base_url = '/v3/tasks'
    end

    paginated_result = TaskListFetcher.new.fetch(pagination_options, indexing_space_guids, app_guid)

    render :ok, json: TaskPresenter.new.present_json_list(paginated_result, base_url, message)
  end

  def create
    FeatureFlag.raise_unless_enabled!('task_creation') unless roles.admin?
    message = TaskCreateMessage.new(params[:body])
    unprocessable!(message.errors.full_messages) unless message.valid?

    app_guid = params[:guid]
    app = AppModel.where(guid: app_guid).eager(:space, space: :organization).first

    app_not_found! unless app && can_read?(app.space.guid, app.space.organization.guid)
    unauthorized! unless can_create?(app.space.guid)

    task     = TaskCreate.new.create(app, message)
    diego_task_runner = VCAP::CloudController::Diego::NsyncClient.new(configuration)
    diego_task_runner.desire_task(task)

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

  def can_create?(space_guid)
    roles.admin? || membership.has_any_roles?([Membership::SPACE_DEVELOPER], space_guid)
  end
end
