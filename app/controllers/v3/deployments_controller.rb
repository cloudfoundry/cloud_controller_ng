require 'messages/deployments_list_message'
require 'fetchers/deployment_list_fetcher'
require 'presenters/v3/deployment_presenter'
require 'actions/deployment_create'
require 'actions/deployment_cancel'

class DeploymentsController < ApplicationController
  def index
    message = DeploymentsListMessage.from_params(query_params)
    invalid_param!(message.errors.full_messages) unless message.valid?
    deployment_list_fetcher = DeploymentListFetcher.new(message: message)
    dataset = if permission_queryer.can_read_globally?
                deployment_list_fetcher.fetch_all
              else
                deployment_list_fetcher.fetch_for_spaces(space_guids: permission_queryer.readable_space_guids)
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

    app_guid = params[:body].dig(:relationships, :app, :data, :guid)
    app = AppModel.find(guid: app_guid)
    unprocessable!('Unable to use app. Ensure that the app exists and you have access to it.') unless app && permission_queryer.can_write_to_space?(app.space.guid)
    unprocessable!('Cannot create a deployment for a STOPPED app.') if app.stopped?

    droplet_guid = params[:body].dig(:droplet, :guid)
    if droplet_guid
      droplet = DropletModel.find(guid: droplet_guid)
    else
      droplet = app.droplet
      unprocessable!('Invalid droplet. Please specify a droplet in the request or set a current droplet for the app.') unless droplet
    end

    begin
      deployment = DeploymentCreate.create(app: app, droplet: droplet, user_audit_info: user_audit_info)
    rescue DeploymentCreate::SetCurrentDropletError => e
      unprocessable!(e.message)
    end

    render status: :created, json: Presenters::V3::DeploymentPresenter.new(deployment)
  end

  def show
    deployment = DeploymentModel.find(guid: params[:guid])

    resource_not_found!(:deployment) unless deployment &&
      permission_queryer.can_read_from_space?(deployment.app.space.guid, deployment.app.space.organization.guid)

    render status: :ok, json: Presenters::V3::DeploymentPresenter.new(deployment)
  end

  def cancel
    deployment = DeploymentModel.find(guid: params[:guid])

    resource_not_found!(:deployment) unless deployment && permission_queryer.can_write_to_space?(deployment.app.space_guid)

    begin
      DeploymentCancel.cancel(deployment: deployment, user_audit_info: user_audit_info)
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
