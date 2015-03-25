module VCAP::CloudController
  class AddRouteToApp
    def initialize(app_model)
      @app_model = app_model
    end

    def add(route)
      AppModelRoute.create(app: @app_model, route: route, type: 'web')
      web_process = @app_model.processes_dataset.where(type: 'web').first
      return if web_process.nil?

      web_process.add_route(route)
      if web_process.dea_update_pending?
        Dea::Client.update_uris(web_process)
      end
    rescue Sequel::ValidationFailed
    end
  end
end
