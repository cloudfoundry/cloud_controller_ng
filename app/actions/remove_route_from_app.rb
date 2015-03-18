module VCAP::CloudController
  class RemoveRouteFromApp
    def initialize(app_model)
      @app_model = app_model
    end

    def remove(route)
      web_process = @app_model.processes_dataset.where(type: 'web').first
      web_process.remove_route(route) unless web_process.nil?
      AppModelRoute.where(route: route, app: @app_model).destroy
    end
  end
end
