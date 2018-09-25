require 'messages/route_mappings_create_message'
require 'messages/route_mappings_update_message'
require 'messages/route_mappings_list_message'
require 'fetchers/route_mapping_list_fetcher'
require 'fetchers/add_route_fetcher'
require 'presenters/v3/paginated_list_presenter'
require 'presenters/v3/route_mapping_presenter'
require 'actions/route_mapping_create'
require 'actions/route_mapping_delete'
require 'controllers/v3/mixins/app_sub_resource'
require 'cloud_controller/copilot/adapter'

class RouteMappingsController < ApplicationController
  include AppSubResource

  def index
    message = RouteMappingsListMessage.from_params(subresource_query_params)
    invalid_param!(message.errors.full_messages) unless message.valid?

    fetcher = RouteMappingListFetcher.new(message: message)

    if app_nested?
      app, dataset = fetcher.fetch_for_app(app_guid: hashed_params[:app_guid])
      app_not_found! unless app && permission_queryer.can_read_from_space?(app.space.guid, app.organization.guid)
    else
      dataset = if permission_queryer.can_read_globally?
                  fetcher.fetch_all
                else
                  fetcher.fetch_for_spaces(space_guids: permission_queryer.readable_space_guids)
                end
    end

    render :ok, json: Presenters::V3::PaginatedListPresenter.new(
      presenter: Presenters::V3::RouteMappingPresenter,
      paginated_result: SequelPaginator.new.get_page(dataset, message.try(:pagination_options)),
      path: base_url(resource: 'route_mappings'),
      message: message
    )
  end

  def create
    message = RouteMappingsCreateMessage.new(hashed_params[:body])
    unprocessable!(message.errors.full_messages) unless message.valid?

    app, route, process, space, org = AddRouteFetcher.fetch(message)

    app_not_found! unless app && permission_queryer.can_read_from_space?(space.guid, org.guid)
    unauthorized! unless permission_queryer.can_write_to_space?(space.guid)
    route_not_found! unless route

    begin
      route_mapping = RouteMappingCreate.add(UserAuditInfo.from_context(SecurityContext), route, process, weight: message.weight)
    rescue ::VCAP::CloudController::RouteMappingCreate::InvalidRouteMapping => e
      unprocessable!(e.message)
    end

    render status: :created, json: Presenters::V3::RouteMappingPresenter.new(route_mapping)
  end

  def update
    message = RouteMappingsUpdateMessage.new(hashed_params[:body])
    unprocessable!(message.errors.full_messages) unless message.valid?

    route_mapping = RouteMappingModel.where(guid: hashed_params[:route_mapping_guid]).eager(:space, space: :organization).first
    route_mapping_not_found! unless route_mapping && permission_queryer.can_read_from_space?(route_mapping.space.guid, route_mapping.space.organization.guid)
    unauthorized! unless permission_queryer.can_write_to_space?(route_mapping.space.guid)

    if message.requested?(:weight)
      route_mapping.update(weight: message.weight)
      Copilot::Adapter.map_route(route_mapping)
    end

    render status: :created, json: Presenters::V3::RouteMappingPresenter.new(route_mapping)
  end

  def show
    route_mapping = RouteMappingModel.where(guid: hashed_params[:route_mapping_guid]).eager(:space, space: :organization).first
    route_mapping_not_found! unless route_mapping && permission_queryer.can_read_from_space?(route_mapping.space.guid, route_mapping.space.organization.guid)
    render status: :ok, json: Presenters::V3::RouteMappingPresenter.new(route_mapping)
  end

  def destroy
    route_mapping = RouteMappingModel.where(guid: hashed_params['route_mapping_guid']).eager(:route, :space, space: :organization, app: :processes).all.first

    route_mapping_not_found! unless route_mapping && permission_queryer.can_read_from_space?(route_mapping.space.guid, route_mapping.space.organization.guid)
    unauthorized! unless permission_queryer.can_write_to_space?(route_mapping.space.guid)

    RouteMappingDelete.new(UserAuditInfo.from_context(SecurityContext)).delete(route_mapping)
    head :no_content
  end

  def route_mapping_not_found!
    resource_not_found!(:route_mapping)
  end

  def route_not_found!
    resource_not_found!(:route)
  end
end
