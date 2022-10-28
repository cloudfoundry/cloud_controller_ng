require 'messages/app_revisions_list_message'
require 'messages/app_deployed_revisions_list_message'
require 'fetchers/app_fetcher'
require 'fetchers/app_revisions_list_fetcher'
require 'presenters/v3/revision_presenter'
require 'controllers/v3/mixins/app_sub_resource'
require 'presenters/v3/revision_environment_variables_presenter'

class AppRevisionsController < ApplicationController
  include AppSubResource

  def index
    message = AppRevisionsListMessage.from_params(query_params)
    invalid_param!(message.errors.full_messages) unless message.valid?

    app, space = AppFetcher.new.fetch(hashed_params[:guid])
    app_not_found! unless app && permission_queryer.can_read_from_space?(space.id, space.organization_id)

    dataset = AppRevisionsListFetcher.fetch(app, message)

    render status: :ok, json: Presenters::V3::PaginatedListPresenter.new(
      presenter: Presenters::V3::RevisionPresenter,
      paginated_result: SequelPaginator.new.get_page(dataset, message.try(:pagination_options)),
      path: "/v3/apps/#{app.guid}/revisions",
      message: message
    )
  end

  def deployed
    message = AppDeployedRevisionsListMessage.from_params(query_params)
    invalid_param!(message.errors.full_messages) unless message.valid?

    app, space = AppFetcher.new.fetch(hashed_params[:guid])
    app_not_found! unless app && permission_queryer.can_read_from_space?(space.id, space.organization_id)

    dataset = AppRevisionsListFetcher.fetch_deployed(app)

    render status: :ok, json: Presenters::V3::PaginatedListPresenter.new(
      presenter: Presenters::V3::RevisionPresenter,
      paginated_result: SequelPaginator.new.get_page(dataset, message.try(:pagination_options)),
      path: "/v3/apps/#{app.guid}/revisions/deployed",
      message: message
    )
  end
end
