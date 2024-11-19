module VCAP::CloudController
  class RouteUpdate
    def update(route:, message:)
      Route.db.transaction do
        if message.requested?(:options)
          route.options = if message.options.nil?
                            nil
                          elsif route.options.nil?
                            message.options
                          else
                            route.options.merge(message.options)
                          end
        end

        route.save
        MetadataUpdate.update(route, message)
      end

      route
    end
  end
end
