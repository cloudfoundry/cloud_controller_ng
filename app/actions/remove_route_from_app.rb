module VCAP::CloudController
  class RemoveRouteFromApp
    def initialize(app_model)
      @app_model = app_model
    end

    def remove(route)
      web_process = @app_model.processes_dataset.where(type: 'web').first
      unless web_process.nil?
        web_process.remove_route(route)

        if web_process.dea_update_pending?
          Dea::Client.update_uris(web_process)
        end
      end

      Repositories::Runtime::AppEventRepository.new.record_unmap_route(@app_model, route, SecurityContext.current_user.try(:guid), SecurityContext.current_user_email)

      AppModelRoute.where(route: route, app: @app_model).destroy
    end
  end
end
