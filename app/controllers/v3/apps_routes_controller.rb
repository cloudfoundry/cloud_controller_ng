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

      app_model = AppFetcher.new.fetch(app_guid)
      app_not_found! if app_model.nil?
      membership = Membership.new(current_user)
      app_not_found! unless membership.space_role?(:developer, app_model.space_guid)

      pagination_options = PaginationOptions.from_params(params)
      routes = SequelPaginator.new.get_page(app_model.routes_dataset, pagination_options)

      routes_json = RoutePresenter.new.present_json_list(routes, "/v3/apps/#{app_guid}/routes")
      [HTTP::OK, routes_json]
    end

    put '/v3/apps/:guid/routes', :add_route
    def add_route(app_guid)
      check_write_permissions!

      opts = MultiJson.load(body)
      app_model, route = AddRouteFetcher.new.fetch(app_guid, opts['route_guid'])
      app_not_found! if app_model.nil?
      route_not_found! if route.nil?

      membership = Membership.new(current_user)
      app_not_found! unless membership.space_role?(:developer, app_model.space_guid)

      AddRouteToApp.new(app_model).add(route)
      [HTTP::NO_CONTENT]
    end

    delete '/v3/apps/:guid/routes', :delete
    def delete(app_guid)
      check_write_permissions!
      opts = MultiJson.load(body)

      app_model, route = DeleteRouteFetcher.new.fetch(app_guid, opts['route_guid'])
      app_not_found! if app_model.nil?
      route_not_found! if route.nil?

      membership = Membership.new(current_user)
      app_not_found! unless membership.space_role?(:developer, app_model.space_guid)

      RemoveRouteFromApp.new(app_model).remove(route)
      [HTTP::NO_CONTENT]
    end

    private

    def app_not_found!
      raise VCAP::Errors::ApiError.new_from_details('ResourceNotFound', 'App not found')
    end

    def route_not_found!
      raise VCAP::Errors::ApiError.new_from_details('ResourceNotFound', 'Route not found')
    end
  end
end
