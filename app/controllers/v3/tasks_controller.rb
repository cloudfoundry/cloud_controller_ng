require 'queries/app_fetcher'
require 'queries/task_list_fetcher'
require 'queries/task_create_fetcher'
require 'queries/task_fetcher'
require 'actions/task_create'
require 'actions/task_cancel'
require 'messages/task_create_message'
require 'messages/tasks_list_message'
require 'presenters/v3/task_presenter'
require 'controllers/v3/mixins/app_subresource'

class TasksController < ApplicationController
  include AppSubresource

  def index
    message = TasksListMessage.from_params(app_subresource_query_params)
    invalid_param!(message.errors.full_messages) unless message.valid?

    pagination_options = PaginationOptions.from_params(query_params)
    invalid_param!(pagination_options.errors.full_messages) unless pagination_options.valid?

    if app_nested?
      app, paginated_result = list_fetcher.fetch_for_app(pagination_options: pagination_options, message: message, app_guid: params[:app_guid])
      app_not_found! unless app && can_read?(app.space.guid, app.organization.guid)
    else
      paginated_result = if roles.admin?
                           list_fetcher.fetch_all(pagination_options: pagination_options, message: message)
                         else
                           list_fetcher.fetch_for_spaces(pagination_options: pagination_options, message: message, space_guids: readable_space_guids)
                         end
    end

    render :ok, json: TaskPresenter.new.present_json_list(paginated_result, base_url(resource: 'tasks'), message)
  end

  def create
    FeatureFlag.raise_unless_enabled!('task_creation') unless roles.admin?

    message = TaskCreateMessage.create_from_http_request(params[:body])
    unprocessable!(message.errors.full_messages) unless message.valid?

    app, space, org, droplet = TaskCreateFetcher.new.fetch(app_guid: params[:app_guid], droplet_guid: message.droplet_guid)

    app_not_found! unless app && can_read?(space.guid, org.guid)
    unauthorized! unless can_create?(space.guid)
    droplet_not_found! if message.requested?(:droplet_guid) && droplet.nil?

    task = TaskCreate.new(configuration).create(app, message, current_user.guid, current_user_email, droplet: droplet)

    render status: :accepted, json: TaskPresenter.new.present_json(task)
  rescue TaskCreate::InvalidTask, TaskCreate::TaskCreateError => e
    unprocessable!(e)
  end

  def cancel
    if app_nested?
      task, app, space, org = TaskFetcher.new.fetch_for_app(task_guid: params[:task_guid], app_guid: params[:app_guid])
      app_not_found! unless app && can_read?(space.guid, org.guid)
      task_not_found! unless task
    else
      task, space, org = TaskFetcher.new.fetch(task_guid: params[:task_guid])
      task_not_found! unless task && can_read?(space.guid, org.guid)
    end

    unauthorized! unless can_cancel?(space.guid)

    TaskCancel.new.cancel(task: task, user: current_user, email: current_user_email)

    render status: :accepted, json: TaskPresenter.new.present_json(task.reload)
  rescue TaskCancel::InvalidCancel => e
    unprocessable!(e)
  end

  def show
    if app_nested?
      task, app, space, org = TaskFetcher.new.fetch_for_app(task_guid: params[:task_guid], app_guid: params[:app_guid])
      app_not_found! unless app && can_read?(space.guid, org.guid)
      task_not_found! unless task
    else
      task, space, org = TaskFetcher.new.fetch(task_guid: params[:task_guid])
      task_not_found! unless task && can_read?(space.guid, org.guid)
    end

    render status: :ok, json: TaskPresenter.new.present_json(task)
  end

  private

  def task_not_found!
    resource_not_found!(:task)
  end

  def droplet_not_found!
    resource_not_found!(:droplet)
  end

  def can_create?(space_guid)
    roles.admin? || membership.has_any_roles?([Membership::SPACE_DEVELOPER], space_guid)
  end
  alias_method :can_cancel?, :can_create?

  def list_fetcher
    @list_fetcher ||= TaskListFetcher.new
  end
end
