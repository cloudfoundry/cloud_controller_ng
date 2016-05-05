require 'cloud_controller/diego/lifecycles/app_lifecycle_provider'
require 'cloud_controller/paging/pagination_options'
require 'actions/app_create'
require 'actions/app_update'
require 'actions/app_delete'
require 'actions/app_start'
require 'actions/app_stop'
require 'actions/set_current_droplet'
require 'messages/apps_list_message'
require 'messages/app_update_message'
require 'messages/app_create_message'
require 'presenters/v3/app_presenter'
require 'presenters/v3/app_env_presenter'
require 'presenters/v3/app_stats_presenter'
require 'presenters/v3/paginated_list_presenter'
require 'queries/app_list_fetcher'
require 'queries/app_fetcher'
require 'queries/app_delete_fetcher'
require 'queries/assign_current_droplet_fetcher'

class AppsV3Controller < ApplicationController
  def index
    message = AppsListMessage.from_params(query_params)
    invalid_param!(message.errors.full_messages) unless message.valid?

    pagination_options = PaginationOptions.from_params(query_params)
    invalid_param!(pagination_options.errors.full_messages) unless pagination_options.valid?

    paginated_result = if roles.admin?
                         AppListFetcher.new.fetch_all(pagination_options, message)
                       else
                         AppListFetcher.new.fetch(pagination_options, message, readable_space_guids)
                       end

    render status: :ok, json: PaginatedListPresenter.new(paginated_result, '/v3/apps', message)
  end

  def show
    app, space, org = AppFetcher.new.fetch(params[:guid])

    app_not_found! unless app && can_read?(space.guid, org.guid)

    render status: :ok, json: AppPresenter.new(app)
  end

  def create
    message = AppCreateMessage.create_from_http_request(params[:body])
    unprocessable!(message.errors.full_messages) unless message.valid?

    space = Space.where(guid: message.space_guid).first
    space_not_found! unless space
    space_not_found! unless can_read?(space.guid, space.organization_guid)
    unauthorized! unless can_write?(message.space_guid)

    if message.lifecycle_type == VCAP::CloudController::PackageModel::DOCKER_TYPE
      FeatureFlag.raise_unless_enabled!('diego_docker')
    end

    lifecycle = AppLifecycleProvider.provide_for_create(message)
    unprocessable!(lifecycle.errors.full_messages) unless lifecycle.valid?

    app = AppCreate.new(current_user, current_user_email).create(message, lifecycle)

    render status: :created, json: AppPresenter.new(app)
  rescue AppCreate::InvalidApp => e
    unprocessable!(e.message)
  end

  def update
    message = AppUpdateMessage.create_from_http_request(params[:body])
    unprocessable!(message.errors.full_messages) unless message.valid?

    app, space, org = AppFetcher.new.fetch(params[:guid])

    app_not_found! unless app && can_read?(space.guid, org.guid)
    unauthorized! unless can_write?(space.guid)

    lifecycle = AppLifecycleProvider.provide_for_update(message, app)
    unprocessable!(lifecycle.errors.full_messages) unless lifecycle.valid?

    app = AppUpdate.new(current_user, current_user_email).update(app, message, lifecycle)

    render status: :ok, json: AppPresenter.new(app)
  rescue AppUpdate::DropletNotFound
    droplet_not_found!
  rescue AppUpdate::InvalidApp => e
    unprocessable!(e.message)
  end

  def destroy
    app, space, org = AppDeleteFetcher.new.fetch(params[:guid])

    app_not_found! unless app && can_read?(space.guid, org.guid)
    unauthorized! unless can_write?(space.guid)

    AppDelete.new(current_user.guid, current_user_email).delete(app)

    head :no_content
  rescue AppDelete::InvalidDelete => e
    unprocessable!(e.message)
  end

  def start
    app, space, org = AppFetcher.new.fetch(params[:guid])
    app_not_found! unless app && can_read?(space.guid, org.guid)
    droplet_not_found! unless app.droplet
    unauthorized! unless can_write?(space.guid)
    if app.droplet.lifecycle_type == DockerLifecycleDataModel::LIFECYCLE_TYPE
      FeatureFlag.raise_unless_enabled!('diego_docker')
    end

    AppStart.new(current_user, current_user_email).start(app)

    render status: :ok, json: AppPresenter.new(app)
  rescue AppStart::InvalidApp => e
    unprocessable!(e.message)
  end

  def stop
    app, space, org = AppFetcher.new.fetch(params[:guid])
    app_not_found! unless app && can_read?(space.guid, org.guid)
    unauthorized! unless can_write?(space.guid)

    AppStop.new(current_user, current_user_email).stop(app)

    render status: :ok, json: AppPresenter.new(app)
  rescue AppStop::InvalidApp => e
    unprocessable!(e.message)
  end

  def show_environment
    app, space, org = AppFetcher.new.fetch(params[:guid])
    app_not_found! unless app && can_read?(space.guid, org.guid)
    unauthorized! unless can_write?(space.guid)

    FeatureFlag.raise_unless_enabled!('space_developer_env_var_visibility') unless roles.admin?

    render status: :ok, json: AppEnvPresenter.new(app)
  end

  def assign_current_droplet
    app_guid = params[:guid]
    droplet_guid = params[:body]['droplet_guid']
    app, space, org, droplet = AssignCurrentDropletFetcher.new.fetch(app_guid, droplet_guid)

    app_not_found! unless app && can_read?(space.guid, org.guid)
    unauthorized! unless can_write?(space.guid)
    unprocessable!('Stop the app before changing droplet') if app.desired_state != 'STOPPED'

    droplet_not_found! if droplet.nil?

    SetCurrentDroplet.new(current_user, current_user_email).update_to(app, droplet)

    render status: :ok, json: DropletPresenter.new(droplet)
  rescue SetCurrentDroplet::InvalidApp => e
    unprocessable!(e.message)
  end

  def current_droplet
    app, space, org = AppFetcher.new.fetch(params[:guid])
    app_not_found! unless app && can_read?(space.guid, org.guid)
    droplet = DropletModel.where(guid: app.droplet_guid).eager(:space, space: :organization).all.first

    droplet_not_found! unless droplet
    render status: :ok, json: DropletPresenter.new(droplet)
  end

  private

  def droplet_not_found!
    resource_not_found!(:droplet)
  end

  def space_not_found!
    resource_not_found!(:space)
  end

  def app_not_found!
    resource_not_found!(:app)
  end

  def instances_reporters
    CloudController::DependencyLocator.instance.instances_reporters
  end
end
