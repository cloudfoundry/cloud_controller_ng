module VCAP::CloudController
  class AddRouteMapping
    class InvalidRouteMapping < StandardError; end

    DUPLICATE_MESSAGE     = 'a duplicate route mapping already exists'
    INVALID_SPACE_MESSAGE = 'the app and route must belong to the same space'

    def initialize(user, user_email)
      @user       = user
      @user_email = user_email
    end

    def add(app, route, process_model)
      validate_space!(app, route)

      process_type  = process_model.nil? ? 'web' : process_model.type
      route_mapping = RouteMappingModel.create(app: app, route: route, process_type: process_type)

      if !process_model.nil?
        process_model.add_route(route)
        update_deas(process_model)
      end

      app_event_repository.record_map_route(
        app,
        route,
        @user.try(:guid),
        @user_email,
        route_mapping: route_mapping
      )

      route_mapping

    rescue Sequel::ValidationFailed => e
      if e.errors && e.errors.on([:app_guid, :route_guid, :process_type]).include?(:unique)
        raise InvalidRouteMapping.new(DUPLICATE_MESSAGE)
      end

      raise InvalidRouteMapping.new(e.message)
    end

    private

    def validate_space!(app, route)
      raise InvalidRouteMapping.new(INVALID_SPACE_MESSAGE) unless app.space.guid == route.space.guid
    end

    def update_deas(process_model)
      if process_model.dea_update_pending?
        Dea::Client.update_uris(process_model)
      end
    end

    def app_event_repository
      Repositories::Runtime::AppEventRepository.new
    end
  end
end
