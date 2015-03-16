require 'queries/add_route_fetcher'
require 'actions/add_route_to_app'

module VCAP::CloudController
  class AppsRoutesController < RestController::BaseController
    put '/v3/apps/:guid/routes', :add_route
    def add_route(app_guid)
      check_write_permissions!

      opts = MultiJson.load(body)
      app, route = AddRouteFetcher.new(current_user).fetch(app_guid, opts['route_guid'])
      app_not_found! if app.nil?
      route_not_found! if route.nil?

      AddRouteToApp.new(app).add(route)
      [HTTP::NO_CONTENT]
    end

    def app_not_found!
      raise VCAP::Errors::ApiError.new_from_details('ResourceNotFound', 'App not found')
    end

    def route_not_found!
      raise VCAP::Errors::ApiError.new_from_details('ResourceNotFound', 'Route not found')
    end
  end
end
