module VCAP::CloudController
  class RouteDeleteAction
    def initialize(user_audit_info)
      @user_audit_info = user_audit_info
    end

    def delete(routes)
      routes.each do |route|
        Route.db.transaction do
          route.destroy
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
