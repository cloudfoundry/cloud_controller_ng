require 'controllers/v3/mixins/sub_resource'
require 'fetchers/process_fetcher'
require 'messages/sidecar_create_message'
require 'messages/sidecars_list_message'
require 'actions/sidecar_create'
require 'presenters/v3/sidecar_presenter'

class SidecarsController < ApplicationController
  include SubResource

  def index
    unprocessable!('No process_guid specified') unless process_nested?
    message = SidecarsListMessage.from_params(query_params)
    invalid_param!(message.errors.full_messages) unless message.valid?

    process, space, org = ProcessFetcher.fetch(process_guid: hashed_params[:process_guid])
    process_not_found! unless process && permission_queryer.can_read_from_space?(space.guid, org.guid)

    render status: :ok, json: Presenters::V3::PaginatedListPresenter.new(
      presenter: Presenters::V3::SidecarPresenter,
      paginated_result: SequelPaginator.new.get_page(process.sidecars_dataset, message.try(:pagination_options)),
      path: base_url(resource: 'sidecars'),
    )
  end

  def create
    app, space, org = AppFetcher.new.fetch(hashed_params[:guid])
    resource_not_found!(:app) unless app && permission_queryer.can_read_from_space?(space.guid, org.guid)
    unauthorized! unless permission_queryer.can_write_to_space?(space.guid)

    message = SidecarCreateMessage.new(hashed_params[:body])
    unprocessable!(message.errors.full_messages) unless message.valid?

    sidecar = SidecarCreate.create(app.guid, message)

    render status: 201, json: Presenters::V3::SidecarPresenter.new(sidecar)
  rescue SidecarCreate::InvalidSidecar => e
    unprocessable!(e.message)
  end

  def show
    sidecar = SidecarModel.find(guid: hashed_params[:guid])
    resource_not_found!(:sidecar) unless sidecar
    app = sidecar.app
    resource_not_found!(:sidecar) unless permission_queryer.can_read_from_space?(app.space.guid, app.space.organization.guid)

    render status: 200, json: Presenters::V3::SidecarPresenter.new(sidecar)
  end

  private

  def process_not_found!
    resource_not_found!(:process)
  end
end
