module VCAP::CloudController
  class RouteMappingCreate
    class InvalidRouteMapping < StandardError; end

    DUPLICATE_MESSAGE     = 'a duplicate route mapping already exists'.freeze
    INVALID_SPACE_MESSAGE = 'the app and route must belong to the same space'.freeze

    def initialize(user, user_email, app, route, process, message)
      @user       = user
      @user_email = user_email
      @app        = app
      @route      = route
      @process    = process
      @message    = message
    end

    def add
      validate!

      route_mapping = RouteMappingModel.new(
        app:          @app,
        route:        @route,
        process_type: @message.process_type,
        app_port:     @message.app_port
      )

      RouteMappingModel.db.transaction do
        route_mapping.save

        if @process
          RouteMapping.create(
            app:      @process,
            route:    @route,
            app_port: @message.app_port
          )
        end

        app_event_repository.record_map_route(
          @app,
          @route,
          @user.try(:guid),
          @user_email,
          route_mapping: route_mapping
        )
      end

      route_mapping

    rescue Sequel::ValidationFailed => e
      if e.errors && e.errors.on([:app_guid, :route_guid, :process_type, :app_port]) && e.errors.on([:app_guid, :route_guid, :process_type, :app_port]).include?(:unique)
        raise InvalidRouteMapping.new(DUPLICATE_MESSAGE)
      end

      raise InvalidRouteMapping.new(e.message)
    end

    private

    def validate!
      validate_space!
      validate_available_port!
    end

    def validate_available_port!
      return if @process.blank?
      validate_web_port! if @process.type == 'web'

      if !@process.ports.nil? && !@process.ports.include?(@message.app_port.to_i)
        raise InvalidRouteMapping.new("Port #{@message.app_port} is not available on the app")
      end

      if @process.ports.blank? && @process.type != 'web'
        raise InvalidRouteMapping.new("Port #{@message.app_port} is not available on the app")
      end
    end

    def validate_web_port!
      if !@message.requested?(:app_port) && !@process.ports.nil? && !@process.ports.include?(@message.app_port.to_i)
        raise InvalidRouteMapping.new('Port must be specified when app process does not have the default port 8080')
      end

      if @process.ports.nil? && @message.app_port.to_i != 8080
        raise InvalidRouteMapping.new("Port #{@message.app_port} is not available on the app")
      end
    end

    def validate_space!
      raise InvalidRouteMapping.new(INVALID_SPACE_MESSAGE) unless @app.space.guid == @route.space.guid
    end

    def app_event_repository
      Repositories::AppEventRepository.new
    end
  end
end
