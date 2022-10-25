require 'fetchers/app_fetcher'
require 'fetchers/task_list_fetcher'
require 'fetchers/task_create_fetcher'
require 'fetchers/task_fetcher'
require 'actions/task_create'
require 'actions/task_cancel'
require 'actions/task_update'
require 'messages/task_create_message'
require 'messages/tasks_list_message'
require 'messages/task_update_message'
require 'presenters/v3/task_presenter'
require 'controllers/v3/mixins/app_sub_resource'

class TasksController < ApplicationController
  include AppSubResource

  def index
    message = TasksListMessage.from_params(subresource_query_params)
    invalid_param!(message.errors.full_messages) unless message.valid?

    show_secrets = false

    if app_nested?
      app, dataset = TaskListFetcher.fetch_for_app(message: message)
      app_not_found! unless app && permission_queryer.can_read_from_space?(app.space.id, app.space.organization_id)

      show_secrets = can_read_secrets?(app.space)
    else
      dataset = if permission_queryer.can_read_globally?
                  TaskListFetcher.fetch_all(message: message)
                else
                  TaskListFetcher.fetch_for_spaces(message: message, space_guids: readable_space_guids)
                end
    end

    render :ok, json: Presenters::V3::PaginatedListPresenter.new(
      presenter: Presenters::V3::TaskPresenter,
      paginated_result: SequelPaginator.new.get_page(dataset, message.try(:pagination_options)),
      path: base_url(resource: 'tasks'),
      message: message,
      show_secrets: show_secrets
    )
  end

  def create
    FeatureFlag.raise_unless_enabled!(:task_creation)

    message = TaskCreateMessage.new(hashed_params[:body])
    unprocessable!(message.errors.full_messages) unless message.valid?

    app, space, droplet = TaskCreateFetcher.new.fetch(app_guid: hashed_params[:app_guid], droplet_guid: message.droplet_guid)

    app_not_found! unless app && permission_queryer.can_read_from_space?(space.id, space.organization_id)
    unauthorized! unless permission_queryer.can_write_to_active_space?(space.id)
    suspended! unless permission_queryer.is_space_active?(space.id)
    droplet_not_found! if message.requested?(:droplet_guid) && droplet.nil?

    task = TaskCreate.new(configuration).create(app, message, user_audit_info, droplet: droplet)
    TelemetryLogger.v3_emit(
      'create-task',
      {
        'app-id' => app.guid,
        'user-id' => current_user.guid
      }
    )
    render status: :accepted, json: Presenters::V3::TaskPresenter.new(task)
  rescue TaskCreate::InvalidTask, TaskCreate::TaskCreateError => e
    unprocessable!(e)
  end

  def cancel
    task, space = TaskFetcher.new.fetch(task_guid: hashed_params[:task_guid])
    task_not_found! unless task && permission_queryer.can_read_from_space?(space.id, space.organization_id)

    unauthorized! unless permission_queryer.can_manage_apps_in_active_space?(space.id)
    suspended! unless permission_queryer.is_space_active?(space.id)
    TaskCancel.new(configuration).cancel(task: task, user_audit_info: user_audit_info)

    render status: :accepted, json: Presenters::V3::TaskPresenter.new(task.reload)
  rescue TaskCancel::InvalidCancel => e
    unprocessable!(e)
  end

  def update
    message = TaskUpdateMessage.new(hashed_params[:body])
    unprocessable!(message.errors.full_messages) unless message.valid?

    task, space = TaskFetcher.new.fetch(task_guid: hashed_params[:task_guid])
    task_not_found! unless task && permission_queryer.can_read_from_space?(space.id, space.organization_id)
    unauthorized! unless permission_queryer.can_write_to_active_space?(space.id)
    suspended! unless permission_queryer.is_space_active?(space.id)

    task = TaskUpdate.new.update(task, message)
    render status: :ok, json: Presenters::V3::TaskPresenter.new(task)
  end

  def show
    task, space = TaskFetcher.new.fetch(task_guid: hashed_params[:task_guid])
    task_not_found! unless task && can_read_task?(space)

    render status: :ok, json: Presenters::V3::TaskPresenter.new(task, show_secrets: can_read_secrets?(space))
  end

  private

  def readable_space_guids
    permission_queryer.readable_space_guids
  end

  def can_read_secrets?(space)
    permission_queryer.can_read_secrets_in_space?(space.id, space.organization_id)
  end

  def can_read_task?(space)
    permission_queryer.can_read_from_space?(space.id, space.organization_id)
  end

  def task_not_found!
    resource_not_found!(:task)
  end

  def droplet_not_found!
    resource_not_found!(:droplet)
  end
end
