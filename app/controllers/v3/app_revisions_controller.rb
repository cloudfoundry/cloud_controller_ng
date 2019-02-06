require 'messages/app_revisions_list_message'
require 'fetchers/app_fetcher'
require 'fetchers/app_revisions_fetcher'
require 'messages/app_revisions_update_message'
require 'actions/app_revisions_update'
require 'presenters/v3/revision_presenter'
require 'controllers/v3/mixins/app_sub_resource'
require 'presenters/v3/revision_environment_variables_presenter'

class AppRevisionsController < ApplicationController
  include AppSubResource

  def index
    message = AppRevisionsListMessage.from_params(query_params)
    invalid_param!(message.errors.full_messages) unless message.valid?

    app, space, org = AppFetcher.new.fetch(hashed_params[:guid])
    app_not_found! unless app && permission_queryer.can_read_from_space?(space.guid, org.guid)

    dataset = AppRevisionsFetcher.fetch(app, message)

    render status: :ok, json: Presenters::V3::PaginatedListPresenter.new(
      presenter: Presenters::V3::RevisionPresenter,
      paginated_result: SequelPaginator.new.get_page(dataset, message.try(:pagination_options)),
      path: "/v3/apps/#{app.guid}/revisions",
      message: message
    )
  end

  def show
    revision = fetch_revision(hashed_params[:revision_guid])
    render status: :ok, json: Presenters::V3::RevisionPresenter.new(revision)
  end

  def update
    message = AppRevisionsUpdateMessage.new(hashed_params[:body])
    unprocessable!(message.errors.full_messages) unless message.valid?

    revision = fetch_revision(hashed_params[:revision_guid], needs_write_permissions: true)

    revision = AppRevisionsUpdate.new.update(revision, message)

    render status: :ok, json: Presenters::V3::RevisionPresenter.new(revision)
  end

  def show_environment_variables
    app, space, org = AppFetcher.new.fetch(hashed_params[:guid])
    app_not_found! unless app && permission_queryer.can_read_from_space?(space.guid, org.guid)
    unauthorized! unless permission_queryer.can_read_secrets_in_space?(space.guid, org.guid)

    revision = RevisionModel.find(guid: hashed_params[:revision_guid])
    resource_not_found!(:revision) unless revision && revision.app_guid == app.guid

    render status: :ok, json: Presenters::V3::RevisionEnvironmentVariablesPresenter.new(revision)
  end

  private

  def fetch_revision(guid, needs_write_permissions: false)
    revision = RevisionModel.find(guid: guid)
    resource_not_found!(:revision) unless revision

    app = revision.app
    space = app.space
    org = space.organization
    app_not_found! unless permission_queryer.can_read_from_space?(space.guid, org.guid)
    unauthorized! if needs_write_permissions && !permission_queryer.can_write_to_space?(space.guid)

    revision
  end
end
