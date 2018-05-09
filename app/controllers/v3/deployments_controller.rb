require 'messages/deployments_list_message'
require 'fetchers/deployment_list_fetcher'
require 'presenters/v3/deployment_presenter'
require 'actions/deployment_create'

class DeploymentsController < ApplicationController
  def index
    message = DeploymentsListMessage.from_params(query_params)
    invalid_param!(message.errors.full_messages) unless message.valid?
    deployment_list_fetcher = DeploymentListFetcher.new(message: message)
    dataset = if can_read_globally?
                deployment_list_fetcher.fetch_all
              else
                deployment_list_fetcher.fetch_for_spaces(space_guids: readable_space_guids)
              end

    render status: :ok, json: Presenters::V3::PaginatedListPresenter.new(
      presenter: Presenters::V3::DeploymentPresenter,
      paginated_result: SequelPaginator.new.get_page(dataset, message.try(:pagination_options)),
      path: '/v3/deployments',
      message: message
    )
  end

  def create
    app_guid = HashUtils.dig(params[:body], :relationships, :app, :data, :guid)
    app = AppModel.find(guid: app_guid)
    unprocessable!('Unable to use app. Ensure that the app exists and you have access to it.') unless app && can_write?(app.space.guid)

    deployment = DeploymentCreate.create(app: app, user_audit_info: user_audit_info)

    response = Presenters::V3::DeploymentPresenter.new(deployment)

    render status: :created, json: response.to_json
  end

  def show
    deployment = DeploymentModel.find(guid: params[:guid])

    resource_not_found!(:deployment) unless deployment &&
      can_read?(deployment.app.space.guid, deployment.app.space.organization.guid)

    render status: :ok, json: Presenters::V3::DeploymentPresenter.new(deployment)
  end
end
