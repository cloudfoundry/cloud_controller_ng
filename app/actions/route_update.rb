module VCAP::CloudController
  class RouteUpdate
    def update(route:, message:)
      Route.db.transaction do
        if message.requested?(:options)
          route.options = if message.options.nil?
                            {}
                          else
                            route.options.symbolize_keys.merge(message.options).compact
                          end
        end

        route.save
        MetadataUpdate.update(route, message)
      end

      route
    end
  end
end
