require 'queries/app_routes_fetcher'
require 'queries/add_route_fetcher'
require 'queries/delete_route_fetcher'
require 'actions/add_route_to_app'
require 'actions/remove_route_from_app'
require 'presenters/v3/route_presenter'
require 'controllers/v3/mixins/app_subresource'

class AppsRoutesController < ApplicationController
  include AppSubresource

  def index
    app_guid = params[:guid]

    app, space, org = AppRoutesFetcher.new.fetch(app_guid)
    app_not_found! unless app && can_read?(space.guid, org.guid)

    pagination_options = PaginationOptions.from_params(params)
    routes = SequelPaginator.new.get_page(app.routes_dataset, pagination_options)

    render :ok, json: RoutePresenter.new.present_json_list(routes, "/v3/apps/#{app_guid}/routes")
  end

  def destroy
    app_guid = params[:guid]

    app, route, space, org = DeleteRouteFetcher.new.fetch(app_guid, params['route_guid'])
    app_not_found! unless app && can_read?(space.guid, org.guid)
    route_not_found! if route.nil?
    unauthorized! unless can_delete?(space.guid)

    RemoveRouteFromApp.new(app).remove(route)

    head :no_content
  end

  private

  def can_write?(space_guid)
    roles.admin? || membership.has_any_roles?([Membership::SPACE_DEVELOPER], space_guid)
  end
  alias_method :can_delete?, :can_write?

  def route_not_found!
    resource_not_found!(:route)
  end
end
