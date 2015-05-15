require 'queries/app_routes_fetcher'
require 'queries/add_route_fetcher'
require 'queries/delete_route_fetcher'
require 'actions/add_route_to_app'
require 'actions/remove_route_from_app'
require 'presenters/v3/route_presenter'

module VCAP::CloudController
  class AppsRoutesController < RestController::BaseController
    get '/v3/apps/:guid/routes', :list
    def list(app_guid)
      check_read_permissions!

      app, space, org = AppRoutesFetcher.new.fetch(app_guid)
      app_not_found! if app.nil? || !can_read?(space.guid, org.guid)

      pagination_options = PaginationOptions.from_params(params)
      routes = SequelPaginator.new.get_page(app.routes_dataset, pagination_options)

      routes_json = RoutePresenter.new.present_json_list(routes, "/v3/apps/#{app_guid}/routes")
      [HTTP::OK, routes_json]
    end

    put '/v3/apps/:guid/routes', :add_route
    def add_route(app_guid)
      check_write_permissions!

      opts = MultiJson.load(body)
      app, route, web_process, space, org = AddRouteFetcher.new.fetch(app_guid, opts['route_guid'])
      app_not_found! if app.nil? || !can_read?(space.guid, org.guid)
      route_not_found! if route.nil?
      unauthorized! unless can_delete?(space.guid)

      app_not_found! unless membership.has_any_roles?([Membership::SPACE_DEVELOPER], app.space_guid)

      AddRouteToApp.new(current_user, current_user_email).add(app, route, web_process)
      [HTTP::NO_CONTENT]
    rescue AddRouteToApp::InvalidRouteMapping => e
      unprocessable!(e.message)
    end

    delete '/v3/apps/:guid/routes', :delete
    def delete(app_guid)
      check_write_permissions!
      opts = MultiJson.load(body)

      app, route, space, org = DeleteRouteFetcher.new.fetch(app_guid, opts['route_guid'])
      app_not_found! if app.nil? || !can_read?(space.guid, org.guid)
      route_not_found! if route.nil?
      unauthorized! unless can_delete?(space.guid)

      app_not_found! unless membership.has_any_roles?([Membership::SPACE_DEVELOPER], app.space_guid)

      RemoveRouteFromApp.new(app).remove(route)
      [HTTP::NO_CONTENT]
    end

    def membership
      @membership ||= Membership.new(current_user)
    end

    private

    def can_read?(space_guid, org_guid)
      membership.has_any_roles?([Membership::SPACE_DEVELOPER,
                                 Membership::SPACE_MANAGER,
                                 Membership::SPACE_AUDITOR,
                                 Membership::ORG_MANAGER], space_guid, org_guid)
    end

    def can_delete?(space_guid)
      membership.has_any_roles?([Membership::SPACE_DEVELOPER], space_guid)
    end

    def app_not_found!
      raise VCAP::Errors::ApiError.new_from_details('ResourceNotFound', 'App not found')
    end

    def route_not_found!
      raise VCAP::Errors::ApiError.new_from_details('ResourceNotFound', 'Route not found')
    end

    def unauthorized!
      raise VCAP::Errors::ApiError.new_from_details('NotAuthorized')
    end
  end
end
