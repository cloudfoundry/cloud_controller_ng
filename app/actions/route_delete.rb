module VCAP::CloudController
  class RouteDeleteAction
    def delete(routes)
      routes.each do |route|
        Route.db.transaction do
          route.destroy
        end
      end

      []
    end
  end
end
