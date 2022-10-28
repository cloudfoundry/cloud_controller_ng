require 'messages/deployments_list_message'
require 'messages/deployment_create_message'
require 'messages/deployment_update_message'
require 'fetchers/deployment_list_fetcher'
require 'presenters/v3/deployment_presenter'
require 'actions/deployment_create'
require 'actions/deployment_update'
require 'actions/deployment_cancel'
require 'cloud_controller/telemetry_logger'

class DeploymentsController < ApplicationController
  def index
    message = DeploymentsListMessage.from_params(query_params)
    invalid_param!(message.errors.full_messages) unless message.valid?
    dataset = if permission_queryer.can_read_globally?
                DeploymentListFetcher.fetch_all(message)
              else
                DeploymentListFetcher.fetch_for_spaces(message, space_guids: permission_queryer.readable_space_guids)
              end

    render status: :ok, json: Presenters::V3::PaginatedListPresenter.new(
      presenter: Presenters::V3::DeploymentPresenter,
      paginated_result: SequelPaginator.new.get_page(dataset, message.try(:pagination_options)),
      path: '/v3/deployments',
      message: message
    )
  end

  def create
    deployments_not_enabled! if Config.config.get(:temporary_disable_deployments)

    message = DeploymentCreateMessage.new(hashed_params[:body])
    unprocessable!(message.errors.full_messages) unless message.valid?

    unable_to_use = 'Unable to use app. Ensure that the app exists and you have access to it and the organization is not suspended.'
    app = AppModel.find(guid: message.app_guid)

    unprocessable!(unable_to_use) unless app && permission_queryer.can_manage_apps_in_active_space?(app.space.id) &&
      permission_queryer.is_space_active?(app.space.id)
    unprocessable!('Cannot create deployment from a revision for an app without revisions enabled') if message.revision_guid && !app.revisions_enabled

    begin
      deployment = DeploymentCreate.create(app: app, user_audit_info: user_audit_info, message: message)
      logger.info("Created deployment #{deployment.guid} for app #{app.guid}")

      TelemetryLogger.v3_emit(
        'create-deployment',
        {
          'app-id' => app.guid,
          'user-id' => current_user.guid
        },
        { 'strategy' => 'rolling' }
      )
    rescue DeploymentCreate::Error => e
      unprocessable!(e.message)
    end

    render status: :created, json: Presenters::V3::DeploymentPresenter.new(deployment)
  end

  def update
    deployment = DeploymentModel.find(guid: hashed_params[:guid])

    resource_not_found!(:deployment) unless deployment && permission_queryer.can_read_from_space?(deployment.app.space.id, deployment.app.space.organization_id)
    unauthorized! unless permission_queryer.can_write_to_active_space?(deployment.app.space.id)
    suspended! unless permission_queryer.is_space_active?(deployment.app.space.id)

    message = VCAP::CloudController::DeploymentUpdateMessage.new(hashed_params[:body])
    unprocessable!(message.errors.full_messages) unless message.valid?

    deployment = VCAP::CloudController::DeploymentUpdate.update(deployment, message)

    render status: :ok, json: Presenters::V3::DeploymentPresenter.new(deployment)
  end

  def show
    deployment = DeploymentModel.find(guid: hashed_params[:guid])

    resource_not_found!(:deployment) unless deployment && permission_queryer.can_read_from_space?(deployment.app.space.id, deployment.app.space.organization_id)

    render status: :ok, json: Presenters::V3::DeploymentPresenter.new(deployment)
  end

  def cancel
    deployment = DeploymentModel.find(guid: hashed_params[:guid])

    resource_not_found!(:deployment) unless deployment && permission_queryer.can_manage_apps_in_active_space?(deployment.app.space.id) &&
      permission_queryer.is_space_active?(deployment.app.space.id)

    begin
      DeploymentCancel.cancel(deployment: deployment, user_audit_info: user_audit_info)
      logger.info("Canceled deployment #{deployment.guid} for app #{deployment.app_guid}")
    rescue DeploymentCancel::Error => e
      unprocessable!(e.message)
    end

    head :ok
  end

  private

  def deployments_not_enabled!
    raise CloudController::Errors::ApiError.new_from_details('DeploymentsDisabled')
  end
end
