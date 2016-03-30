require 'messages/route_mappings_create_message'
require 'messages/route_mappings_list_message'
require 'queries/route_mapping_list_fetcher'
require 'queries/add_route_fetcher'
require 'presenters/v3/route_mapping_presenter'
require 'actions/route_mapping_create'
require 'actions/route_mapping_delete'
require 'controllers/v3/mixins/app_subresource'

class RouteMappingsController < ApplicationController
  include AppSubresource

  def index
    app_guid = params[:app_guid]
    app, space, org = AppFetcher.new.fetch(app_guid)
    app_not_found! unless app && can_read?(space.guid, org.guid)

    message = RouteMappingsListMessage.from_params(query_params)
    invalid_param!(message.errors.full_messages) unless message.valid?

    pagination_options = PaginationOptions.from_params(query_params)
    invalid_param!(pagination_options.errors.full_messages) unless pagination_options.valid?

    paginated_result = RouteMappingListFetcher.new.fetch(pagination_options, app_guid)

    render :ok, json: RouteMappingPresenter.new.present_json_list(paginated_result, "/v3/apps/#{app_guid}/route_mappings", message)
  end

  def create
    message = RouteMappingsCreateMessage.create_from_http_request(params[:body])
    unprocessable!(message.errors.full_messages) unless message.valid?

    process_type = message.process_type || 'web'

    app, route, process, space, org = AddRouteFetcher.new.fetch(
      message.app_guid,
      message.route_guid,
      process_type
    )

    app_not_found! unless app && can_read?(space.guid, org.guid)
    unauthorized! unless can_write?(space.guid)
    route_not_found! unless route

    begin
      route_mapping = RouteMappingCreate.new(current_user, current_user_email).add(app, route, process, process_type)
    rescue RouteMappingCreate::InvalidRouteMapping => e
      unprocessable!(e.message)
    end

    render status: :created, json: RouteMappingPresenter.new.present_json(route_mapping)
  end

  def show
    route_mapping = RouteMappingModel.where(guid: params[:route_mapping_guid]).eager(:space, space: :organization).first
    route_mapping_not_found! unless route_mapping && can_read?(route_mapping.space.guid, route_mapping.space.organization.guid)
    render status: :ok, json: RouteMappingPresenter.new.present_json(route_mapping)
  end

  def destroy
    route_mapping = RouteMappingModel.where(guid: params['route_mapping_guid']).eager(:route, :space, space: :organization, app: :processes).all.first

    route_mapping_not_found! unless route_mapping && can_read?(route_mapping.space.guid, route_mapping.space.organization.guid)
    unauthorized! unless can_delete?(route_mapping.space.guid)

    RouteMappingDelete.new(current_user, current_user_email).delete(route_mapping)
    head :no_content
  end

  def route_mapping_not_found!
    resource_not_found!(:route_mapping)
  end

  def route_not_found!
    resource_not_found!(:route)
  end

  def can_write?(space_guid)
    roles.admin? || membership.has_any_roles?([Membership::SPACE_DEVELOPER], space_guid)
  end
  alias_method :can_delete?, :can_write?
end
