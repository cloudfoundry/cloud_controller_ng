require 'controllers/v3/mixins/sub_resource'
require 'fetchers/process_fetcher'
require 'messages/sidecar_create_message'
require 'messages/sidecar_update_message'
require 'messages/sidecars_list_message'
require 'actions/sidecar_create'
require 'actions/sidecar_update'
require 'presenters/v3/sidecar_presenter'
require 'fetchers/sidecar_list_fetcher'

class SidecarsController < ApplicationController
  include SubResource

  def index_by_app
    message = SidecarsListMessage.from_params(query_params)
    invalid_param!(message.errors.full_messages) unless message.valid?

    app, dataset = SidecarListFetcher.fetch_for_app(message, hashed_params[:app_guid])

    resource_not_found!(:app) unless app && permission_queryer.can_read_from_space?(app.space.id, app.space.organization_id)
    render status: :ok, json: Presenters::V3::PaginatedListPresenter.new(
      presenter: Presenters::V3::SidecarPresenter,
      paginated_result: SequelPaginator.new.get_page(dataset, message.try(:pagination_options)),
      path: base_url(resource: 'sidecars'),
      )
  end

  def index_by_process
    message = SidecarsListMessage.from_params(query_params)
    invalid_param!(message.errors.full_messages) unless message.valid?

    process, dataset = SidecarListFetcher.fetch_for_process(message, hashed_params[:process_guid])

    resource_not_found!(:process) unless process && permission_queryer.can_read_from_space?(process.space.id, process.space.organization_id)
    render status: :ok, json: Presenters::V3::PaginatedListPresenter.new(
      presenter: Presenters::V3::SidecarPresenter,
      paginated_result: SequelPaginator.new.get_page(dataset, message.try(:pagination_options)),
      path: base_url(resource: 'sidecars'),
      )
  end

  def show
    sidecar = SidecarModel.find(guid: hashed_params[:guid])
    resource_not_found!(:sidecar) unless sidecar

    app = sidecar.app
    resource_not_found!(:sidecar) unless permission_queryer.can_read_from_space?(app.space.id, app.space.organization_id)

    render status: 200, json: Presenters::V3::SidecarPresenter.new(sidecar)
  end

  def create
    app, space = AppFetcher.new.fetch(hashed_params[:guid])
    resource_not_found!(:app) unless app && permission_queryer.can_read_from_space?(space.id, space.organization_id)
    unauthorized! unless permission_queryer.can_write_to_active_space?(space.id)
    suspended! unless permission_queryer.is_space_active?(space.id)

    message = SidecarCreateMessage.new(hashed_params[:body])
    unprocessable!(message.errors.full_messages) unless message.valid?

    sidecar = SidecarCreate.create(app.guid, message)

    TelemetryLogger.v3_emit(
      'create-sidecar',
        {
          'app-id' => app.guid,
          'user-id' => current_user.guid,
        },
      {
        'origin' => 'user',
        'memory-in-mb' => sidecar.memory,
        'process-types' => sidecar.process_types,
      }
    )
    render status: 201, json: Presenters::V3::SidecarPresenter.new(sidecar)
  rescue SidecarCreate::InvalidSidecar => e
    unprocessable!(e.message)
  end

  def update
    sidecar = SidecarModel.find(guid: params[:guid])

    resource_not_found!(:sidecar) unless sidecar
    space = sidecar.app.space
    resource_not_found!(:sidecar) unless permission_queryer.can_read_from_space?(space.id, space.organization_id)
    unauthorized! unless permission_queryer.can_write_to_active_space?(space.id)
    suspended! unless permission_queryer.is_space_active?(space.id)

    message = SidecarUpdateMessage.new(hashed_params[:body])
    unprocessable!(message.errors.full_messages) unless message.valid?

    sidecar = SidecarUpdate.update(sidecar, message)

    render status: 200, json: Presenters::V3::SidecarPresenter.new(sidecar)
  rescue SidecarUpdate::InvalidSidecar => e
    unprocessable!(e.message)
  end

  def destroy
    sidecar = SidecarModel.find(guid: hashed_params[:guid])
    resource_not_found!(:sidecar) unless sidecar
    space = sidecar.app.space
    resource_not_found!(:sidecar) unless permission_queryer.can_read_from_space?(space.id, space.organization_id)
    unauthorized! unless permission_queryer.can_write_to_active_space?(space.id)
    suspended! unless permission_queryer.is_space_active?(space.id)

    SidecarDelete.delete(sidecar)
    head :no_content
  end
end
