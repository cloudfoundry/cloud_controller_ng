module VCAP::CloudController
  class AddRouteToApp
    def initialize(app)
      @app = app
    end

    def add(route)
      AppModelRoute.create(apps_v3_id: @app.id, route_id: route.id, type: 'web')
      web_process = @app.processes_dataset.where(type: 'web').first
      web_process.add_route(route) unless web_process.nil?
    end
  end
end
