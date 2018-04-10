require 'messages/route_mappings_create_message'
require 'messages/route_mappings_list_message'
require 'fetchers/route_mapping_list_fetcher'
require 'fetchers/add_route_fetcher'
require 'presenters/v3/paginated_list_presenter'
require 'presenters/v3/route_mapping_presenter'
require 'actions/route_mapping_create'
require 'actions/route_mapping_delete'
require 'controllers/v3/mixins/app_sub_resource'

class RouteMappingsController < ApplicationController
  include AppSubResource

  def index
    message = RouteMappingsListMessage.from_params(subresource_query_params)
    invalid_param!(message.errors.full_messages) unless message.valid?

    fetcher = RouteMappingListFetcher.new(message: message)

    if app_nested?
      app, dataset = fetcher.fetch_for_app(app_guid: params[:app_guid])
      app_not_found! unless app && can_read?(app.space.guid, app.organization.guid)
    else
      dataset = if can_read_globally?
                  fetcher.fetch_all
                else
                  fetcher.fetch_for_spaces(space_guids: readable_space_guids)
                end
    end

    render :ok, json: Presenters::V3::PaginatedListPresenter.new(dataset: dataset, path: base_url(resource: 'route_mappings'), message: message)
  end

  def create
    message = RouteMappingsCreateMessage.create_from_http_request(params[:body])
    unprocessable!(message.errors.full_messages) unless message.valid?

    app, route, process, space, org = AddRouteFetcher.fetch(message)

    app_not_found! unless app && can_read?(space.guid, org.guid)
    unauthorized! unless can_write?(space.guid)
    route_not_found! unless route

    begin
      route_mapping = RouteMappingCreate.add(UserAuditInfo.from_context(SecurityContext), route, process)
    rescue ::VCAP::CloudController::RouteMappingCreate::InvalidRouteMapping => e
      unprocessable!(e.message)
    end

    render status: :created, json: Presenters::V3::RouteMappingPresenter.new(route_mapping)
  end

  def show
    route_mapping = RouteMappingModel.where(guid: params[:route_mapping_guid]).eager(:space, space: :organization).first
    route_mapping_not_found! unless route_mapping && can_read?(route_mapping.space.guid, route_mapping.space.organization.guid)
    render status: :ok, json: Presenters::V3::RouteMappingPresenter.new(route_mapping)
  end

  def destroy
    route_mapping = RouteMappingModel.where(guid: params['route_mapping_guid']).eager(:route, :space, space: :organization, app: :processes).all.first

    route_mapping_not_found! unless route_mapping && can_read?(route_mapping.space.guid, route_mapping.space.organization.guid)
    unauthorized! unless can_write?(route_mapping.space.guid)

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
