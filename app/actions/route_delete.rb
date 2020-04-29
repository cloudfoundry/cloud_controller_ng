module VCAP::CloudController
  class RouteDeleteAction
    def initialize(user_audit_info)
      @user_audit_info = user_audit_info
    end

    def delete(routes)
      if VCAP::CloudController::Config.kubernetes_api_configured?
        client = CloudController::DependencyLocator.instance.route_crd_client
      end
      routes.each do |route|
        Route.db.transaction do
          route.destroy
        end

        if client
          client.delete_route(route)
        end

        Repositories::RouteEventRepository.new.record_route_delete_request(
          route,
          @user_audit_info,
          true
        )
      end

      []
    end
  end
end
