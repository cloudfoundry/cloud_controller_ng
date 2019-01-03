require 'messages/app_revisions_list_message'
require 'fetchers/app_fetcher'
require 'presenters/v3/revision_presenter'
require 'controllers/v3/mixins/app_sub_resource'

class AppRevisionsController < ApplicationController
  include AppSubResource

  def index
    message = AppRevisionsListMessage.from_params(query_params)
    invalid_param!(message.errors.full_messages) unless message.valid?

    app, space, org = AppFetcher.new.fetch(hashed_params[:guid])
    app_not_found! unless app && permission_queryer.can_read_from_space?(space.guid, org.guid)

    render status: :ok, json: Presenters::V3::PaginatedListPresenter.new(
      presenter: Presenters::V3::RevisionPresenter,
      paginated_result: SequelPaginator.new.get_page(RevisionModel.where(app: app), message.try(:pagination_options)),
      path: "/v3/apps/#{app.guid}/revisions",
      message: message
    )
  end

  def show
    app, space, org = AppFetcher.new.fetch(hashed_params[:guid])
    app_not_found! unless app && permission_queryer.can_read_from_space?(space.guid, org.guid)

    revision = RevisionModel.find(guid: hashed_params[:revision_guid])
    resource_not_found!(:revision) unless revision && revision.app_guid == app.guid

    render status: :ok, json: Presenters::V3::RevisionPresenter.new(revision)
  end
end
