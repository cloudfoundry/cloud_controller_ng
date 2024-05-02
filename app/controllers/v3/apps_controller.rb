require 'cloud_controller/diego/lifecycles/app_lifecycle_provider'
require 'cloud_controller/paging/pagination_options'
require 'cloud_controller/telemetry_logger'
require 'actions/app_create'
require 'actions/app_update'
require 'actions/app_patch_environment_variables'
require 'actions/app_delete'
require 'actions/app_restart'
require 'actions/app_apply_manifest'
require 'actions/app_start'
require 'actions/app_stop'
require 'actions/app_assign_droplet'
require 'decorators/include_space_decorator'
require 'decorators/include_organization_decorator'
require 'decorators/include_space_organization_decorator'
require 'messages/apps_list_message'
require 'messages/app_show_message'
require 'messages/app_update_message'
require 'messages/app_create_message'
require 'messages/update_environment_variables_message'
require 'messages/app_manifest_message'
require 'messages/app_builds_list_message'
require 'presenters/v3/app_presenter'
require 'presenters/v3/app_env_presenter'
require 'presenters/v3/app_environment_variables_presenter'
require 'presenters/v3/paginated_list_presenter'
require 'presenters/v3/app_droplet_relationship_presenter'
require 'presenters/v3/build_presenter'
require 'fetchers/app_list_fetcher'
require 'fetchers/app_builds_list_fetcher'
require 'fetchers/app_fetcher'
require 'fetchers/assign_current_droplet_fetcher'
require 'repositories/app_event_repository'

class AppsV3Controller < ApplicationController
  def index
    message = AppsListMessage.from_params(query_params)
    invalid_param!(message.errors.full_messages) unless message.valid?

    eager_loaded_associations = Presenters::V3::AppPresenter.associated_resources

    decorators = []
    decorators << IncludeSpaceDecorator if IncludeSpaceDecorator.match?(message.include)
    if IncludeOrganizationDecorator.match?(message.include)
      decorators << IncludeOrganizationDecorator
      eager_loaded_associations << :space
    end

    dataset = if permission_queryer.can_read_globally?
                AppListFetcher.fetch_all(message, eager_loaded_associations:)
              else
                AppListFetcher.fetch(message, permission_queryer.readable_space_guids, eager_loaded_associations:)
              end

    page_results = SequelPaginator.new.get_page(dataset, message.try(:pagination_options))
    handle_order_by_presented_value(page_results)

    render status: :ok,
           json: Presenters::V3::PaginatedListPresenter.new(
             presenter: Presenters::V3::AppPresenter,
             paginated_result: page_results,
             path: '/v3/apps',
             message: message,
             decorators: decorators
           )
  end

  def show
    message = AppShowMessage.from_params(query_params)

    invalid_param!(message.errors.full_messages) unless message.valid?

    app, space = AppFetcher.new.fetch(hashed_params[:guid])

    app_not_found! unless app && permission_queryer.can_read_from_space?(space.id, space.organization_id)

    decorators = []
    decorators << IncludeSpaceDecorator if IncludeSpaceDecorator.match?(message.include)
    decorators << IncludeOrganizationDecorator if IncludeOrganizationDecorator.match?(message.include)

    render status: :ok, json: Presenters::V3::AppPresenter.new(
      app,
      show_secrets: permission_queryer.can_read_secrets_in_space?(space.id, space.organization_id),
      decorators: decorators
    )
  end

  def create
    message = AppCreateMessage.new(hashed_params[:body])
    unprocessable!(message.errors.full_messages) unless message.valid?

    space = Space.where(guid: message.space_guid).first
    unprocessable_space! unless space && permission_queryer.can_read_from_space?(space.id, space.organization_id)
    unauthorized! unless permission_queryer.can_write_to_active_space?(space.id)
    suspended! unless permission_queryer.is_space_active?(space.id)
    FeatureFlag.raise_unless_enabled!(:diego_docker) if message.lifecycle_type == VCAP::CloudController::PackageModel::DOCKER_TYPE
    lifecycle = AppLifecycleProvider.provide_for_create(message)
    FeatureFlag.raise_unless_enabled!(:diego_cnb) if lifecycle.type == VCAP::CloudController::Lifecycles::CNB
    unprocessable!(lifecycle.errors.full_messages) unless lifecycle.valid?

    app = AppCreate.new(user_audit_info).create(message, lifecycle)
    TelemetryLogger.v3_emit(
      'create-app',
      {
        'app-id' => app.guid,
        'user-id' => current_user.guid
      }
    )

    render status: :created, json: Presenters::V3::AppPresenter.new(app)
  rescue AppCreate::InvalidApp => e
    unprocessable!(e.message)
  end

  def update
    message = AppUpdateMessage.new(hashed_params[:body])
    unprocessable!(message.errors.full_messages) unless message.valid?

    app, space = AppFetcher.new.fetch(hashed_params[:guid])

    app_not_found! unless app && permission_queryer.can_read_from_space?(space.id, space.organization_id)
    unauthorized! unless permission_queryer.can_write_to_active_space?(space.id)
    suspended! unless permission_queryer.is_space_active?(space.id)

    lifecycle = AppLifecycleProvider.provide_for_update(message, app)
    unprocessable!(lifecycle.errors.full_messages) unless lifecycle.valid?

    app = AppUpdate.new(user_audit_info).update(app, message, lifecycle)
    TelemetryLogger.v3_emit(
      'update-app',
      {
        'app-id' => app.guid,
        'user-id' => current_user.guid
      }
    )

    render status: :ok, json: Presenters::V3::AppPresenter.new(app)
  rescue AppUpdate::DropletNotFound
    droplet_not_found!
  rescue AppUpdate::InvalidApp => e
    unprocessable!(e.message)
  end

  def destroy
    app, space = AppFetcher.new.fetch(hashed_params[:guid])

    app_not_found! unless app && permission_queryer.can_read_from_space?(space.id, space.organization_id)
    unauthorized! unless permission_queryer.can_write_to_active_space?(space.id)
    suspended! unless permission_queryer.is_space_active?(space.id)

    delete_action = AppDelete.new(user_audit_info)
    deletion_job  = VCAP::CloudController::Jobs::DeleteActionJob.new(AppModel, app.guid, delete_action)

    job = Jobs::Enqueuer.new(deletion_job, queue: Jobs::Queues.generic).enqueue_pollable do |pollable_job|
      DeleteAppErrorTranslatorJob.new(pollable_job)
    end
    VCAP::AppLogEmitter.emit(app.guid, "Enqueued job to delete app with guid #{app.guid}")
    head HTTP::ACCEPTED, 'Location' => url_builder.build_url(path: "/v3/jobs/#{job.guid}")
  end

  def start
    app, space = AppFetcher.new.fetch(hashed_params[:guid])
    app_not_found! unless app && permission_queryer.can_read_from_space?(space.id, space.organization_id)
    unprocessable_lacking_droplet! unless app.droplet
    unauthorized! unless permission_queryer.can_manage_apps_in_active_space?(space.id)
    suspended! unless permission_queryer.is_space_active?(space.id)

    FeatureFlag.raise_unless_enabled!(:diego_docker) if app.lifecycle_type == DockerLifecycleDataModel::LIFECYCLE_TYPE
    FeatureFlag.raise_unless_enabled!(:diego_cnb) if app.lifecycle_type == CNBLifecycleDataModel::LIFECYCLE_TYPE

    AppStart.start(app:, user_audit_info:)
    TelemetryLogger.v3_emit(
      'start-app',
      {
        'app-id' => app.guid,
        'user-id' => current_user.guid
      }
    )
    render status: :ok, json: Presenters::V3::AppPresenter.new(app)
  rescue AppStart::InvalidApp => e
    unprocessable!(e.message)
  end

  def stop
    app, space = AppFetcher.new.fetch(hashed_params[:guid])
    app_not_found! unless app && permission_queryer.can_read_from_space?(space.id, space.organization_id)
    unauthorized! unless permission_queryer.can_manage_apps_in_active_space?(space.id)
    suspended! unless permission_queryer.is_space_active?(space.id)

    AppStop.stop(app:, user_audit_info:)
    TelemetryLogger.v3_emit(
      'stop-app',
      {
        'app-id' => app.guid,
        'user-id' => current_user.guid
      }
    )

    render status: :ok, json: Presenters::V3::AppPresenter.new(app)
  rescue AppStop::InvalidApp => e
    unprocessable!(e.message)
  end

  def restart
    app, space = AppFetcher.new.fetch(hashed_params[:guid])
    app_not_found! unless app && permission_queryer.can_read_from_space?(space.id, space.organization_id)
    unprocessable_lacking_droplet! unless app.droplet
    unauthorized! unless permission_queryer.can_manage_apps_in_active_space?(space.id)
    suspended! unless permission_queryer.is_space_active?(space.id)

    FeatureFlag.raise_unless_enabled!(:diego_docker) if app.lifecycle_type == DockerLifecycleDataModel::LIFECYCLE_TYPE
    FeatureFlag.raise_unless_enabled!(:diego_cnb) if app.lifecycle_type == CNBLifecycleDataModel::LIFECYCLE_TYPE

    AppRestart.restart(app: app, config: Config.config, user_audit_info: user_audit_info)
    TelemetryLogger.v3_emit(
      'restart-app',
      {
        'app-id' => app.guid,
        'user-id' => current_user.guid
      }
    )
    render status: :ok, json: Presenters::V3::AppPresenter.new(app)
  rescue AppRestart::Error => e
    unprocessable!(e.message)
  rescue ::VCAP::CloudController::Diego::Runner::CannotCommunicateWithDiegoError => e
    logger.error(e.message)
    raise CloudController::Errors::ApiError.new_from_details('RunnerUnavailable', 'Unable to communicate with Diego')
  end

  def builds
    message = AppBuildsListMessage.from_params(query_params)
    invalid_param!(message.errors.full_messages) unless message.valid?

    app, space = AppFetcher.new.fetch(hashed_params[:guid])
    app_not_found! unless app && permission_queryer.can_read_from_space?(space.id, space.organization_id)

    dataset = AppBuildsListFetcher.fetch_all(app.guid, message)
    render status: :ok, json: Presenters::V3::PaginatedListPresenter.new(
      presenter: Presenters::V3::BuildPresenter,
      paginated_result: SequelPaginator.new.get_page(dataset, message.try(:pagination_options)),
      path: "/v3/apps/#{app.guid}/builds",
      message: message
    )
  end

  def show_env
    app, space = AppFetcher.new.fetch(hashed_params[:guid])

    FeatureFlag.raise_unless_enabled!(:env_var_visibility)

    app_not_found! unless app && permission_queryer.can_read_from_space?(space.id, space.organization_id)
    unauthorized! unless permission_queryer.can_read_app_environment_variables?(space.id, space.organization_id)
    show_secrets = permission_queryer.can_read_system_environment_variables?(space.id, space.organization_id)

    FeatureFlag.raise_unless_enabled!(:space_developer_env_var_visibility)

    Repositories::AppEventRepository.new.record_app_show_env(app, user_audit_info)

    render status: :ok, json: Presenters::V3::AppEnvPresenter.new(app, show_secrets)
  end

  def show_environment_variables
    FeatureFlag.raise_unless_enabled!(:env_var_visibility)

    app, space = AppFetcher.new.fetch(hashed_params[:guid])

    app_not_found! unless app && permission_queryer.can_read_from_space?(space.id, space.organization_id)
    unauthorized! unless permission_queryer.can_read_app_environment_variables?(space.id, space.organization_id)

    FeatureFlag.raise_unless_enabled!(:space_developer_env_var_visibility)

    Repositories::AppEventRepository.new.record_app_show_environment_variables(app, user_audit_info)

    render status: :ok, json: Presenters::V3::AppEnvironmentVariablesPresenter.new(app)
  end

  def update_environment_variables
    app, space = AppFetcher.new.fetch(hashed_params[:guid])

    app_not_found! unless app && permission_queryer.can_read_from_space?(space.id, space.organization_id)
    unauthorized! unless permission_queryer.can_manage_apps_in_active_space?(space.id)
    suspended! unless permission_queryer.is_space_active?(space.id)

    message = UpdateEnvironmentVariablesMessage.new(hashed_params[:body])
    unprocessable!(message.errors.full_messages) unless message.valid?

    app = AppPatchEnvironmentVariables.new(user_audit_info).patch(app, message)

    render status: :ok, json: Presenters::V3::AppEnvironmentVariablesPresenter.new(app)
  end

  def assign_current_droplet
    app_guid     = hashed_params[:guid]
    droplet_guid = hashed_params[:body].dig(:data, :guid)
    cannot_remove_droplet! if hashed_params[:body].key?('data') && droplet_guid.nil?
    app, space, droplet = AssignCurrentDropletFetcher.new.fetch(app_guid, droplet_guid)

    app_not_found! unless app && permission_queryer.can_read_from_space?(space.id, space.organization_id)
    unauthorized! unless permission_queryer.can_manage_apps_in_active_space?(space.id)
    suspended! unless permission_queryer.is_space_active?(space.id)
    deployment_in_progress! if app.deploying?

    AppAssignDroplet.new(user_audit_info).assign(app, droplet)

    render status: :ok, json: Presenters::V3::AppDropletRelationshipPresenter.new(
      resource_path: "apps/#{app_guid}",
      related_instance: droplet,
      relationship_name: 'current_droplet',
      related_resource_name: 'droplets',
      app_model: app
    )
  rescue AppAssignDroplet::Error => e
    unprocessable!(e.message)
  end

  def current_droplet_relationship
    app, space = AppFetcher.new.fetch(hashed_params[:guid])
    app_not_found! unless app && permission_queryer.can_read_from_space?(space.id, space.organization_id)
    droplet = DropletModel.where(guid: app.droplet_guid).first

    droplet_not_found! unless droplet
    render status: :ok, json: Presenters::V3::AppDropletRelationshipPresenter.new(
      resource_path: "apps/#{app.guid}",
      related_instance: droplet,
      relationship_name: 'current_droplet',
      related_resource_name: 'droplets',
      app_model: app
    )
  end

  def current_droplet
    app, space = AppFetcher.new.fetch(hashed_params[:guid])
    app_not_found! unless app && permission_queryer.can_read_from_space?(space.id, space.organization_id)
    droplet = DropletModel.where(guid: app.droplet_guid).first

    droplet_not_found! unless droplet
    render status: :ok, json: Presenters::V3::DropletPresenter.new(droplet)
  end

  def show_permissions
    app, space = AppFetcher.new.fetch(hashed_params[:guid])

    app_not_found! unless app && permission_queryer.can_read_from_space?(space.id, space.organization_id)

    render status: :ok, json: {
      read_basic_data: true,
      read_sensitive_data: permission_queryer.can_read_secrets_in_space?(space.id, space.organization_id)
    }
  end

  class DeleteAppErrorTranslatorJob < VCAP::CloudController::Jobs::ErrorTranslatorJob
    include V3ErrorsHelper

    def translate_error(e)
      if e.instance_of?(VCAP::CloudController::AppDelete::SubResourceError)
        underlying_errors = e.underlying_errors.map { |err| unprocessable(err.message) }
        e = CloudController::Errors::CompoundError.new(underlying_errors)
      end
      e
    end
  end

  private

  def handle_order_by_presented_value(page_results)
    return unless page_results.try(:pagination_options).try(:order_by) == 'desired_state'

    page_results.pagination_options.order_by = 'state'
  end

  def deployment_in_progress!
    unprocessable!(
      'Unable to assign current droplet while the app has a deployment in progress. Wait for the deployment to complete or cancel it.'
    )
  end

  def droplet_not_found!
    resource_not_found!(:droplet)
  end

  def unprocessable_lacking_droplet!
    unprocessable!('Assign a droplet before starting this app.')
  end

  def unprocessable_space!
    unprocessable!('Invalid space. Ensure that the space exists and you have access to it.')
  end

  def app_not_found!
    resource_not_found!(:app)
  end

  def cannot_remove_droplet!
    unprocessable!('Current droplet cannot be removed. Replace it with a preferred droplet.')
  end

  def instances_reporters
    CloudController::DependencyLocator.instance.instances_reporters
  end
end
