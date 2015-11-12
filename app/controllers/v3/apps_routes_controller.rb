require 'queries/app_routes_fetcher'
require 'queries/add_route_fetcher'
require 'queries/delete_route_fetcher'
require 'actions/add_route_to_app'
require 'actions/remove_route_from_app'
require 'presenters/v3/route_presenter'

class AppsRoutesController < ApplicationController
  def index
    app_guid = params[:guid]

    app, space, org = AppRoutesFetcher.new.fetch(app_guid)
    app_not_found! if app.nil? || !can_read?(space.guid, org.guid)

    pagination_options = PaginationOptions.from_params(params)
    routes = SequelPaginator.new.get_page(app.routes_dataset, pagination_options)

    render :ok, json: RoutePresenter.new.present_json_list(routes, "/v3/apps/#{app_guid}/routes")
  end

  def add_route
    app_guid = params[:guid]

    app, route, web_process, space, org = AddRouteFetcher.new.fetch(app_guid, params['route_guid'])
    app_not_found! if app.nil? || !can_read?(space.guid, org.guid)
    route_not_found! if route.nil?
    unauthorized! unless can_write?(space.guid)

    begin
      AddRouteToApp.new(current_user, current_user_email).add(app, route, web_process)
    rescue AddRouteToApp::InvalidRouteMapping => e
      unprocessable!(e.message)
    end

    head :no_content
  end

  def destroy
    app_guid = params[:guid]

    app, route, space, org = DeleteRouteFetcher.new.fetch(app_guid, params['route_guid'])
    app_not_found! if app.nil? || !can_read?(space.guid, org.guid)
    route_not_found! if route.nil?
    unauthorized! unless can_delete?(space.guid)

    RemoveRouteFromApp.new(app).remove(route)

    head :no_content
  end

  private

  def membership
    @membership ||= Membership.new(current_user)
  end

  def can_read?(space_guid, org_guid)
    roles.admin? ||
      membership.has_any_roles?([Membership::SPACE_DEVELOPER,
                                 Membership::SPACE_MANAGER,
                                 Membership::SPACE_AUDITOR,
                                 Membership::ORG_MANAGER], space_guid, org_guid)
  end

  def can_write?(space_guid)
    roles.admin? || membership.has_any_roles?([Membership::SPACE_DEVELOPER], space_guid)
  end
  alias_method :can_delete?, :can_write?

  def app_not_found!
    raise VCAP::Errors::ApiError.new_from_details('ResourceNotFound', 'App not found')
  end

  def route_not_found!
    raise VCAP::Errors::ApiError.new_from_details('ResourceNotFound', 'Route not found')
  end
end
