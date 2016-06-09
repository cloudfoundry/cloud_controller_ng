module VCAP::CloudController
  class RouteMappingCreate
    class InvalidRouteMapping < StandardError; end

    DUPLICATE_MESSAGE = 'Duplicate Route Mapping - Only one route mapping may exist for an application, route, and port'.freeze
    INVALID_SPACE_MESSAGE = 'the app and route must belong to the same space'.freeze
    UNAVAILABLE_APP_PORT_MESSAGE_FORMAT = 'Port %s is not available on the app\'s process'.freeze

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
      validate_web_port!
      validate_non_web_port!
    end

    def validate_non_web_port!
      return if @process.type == 'web'
      raise_unvailable_port! if @process.ports.blank?
      raise_unvailable_port! unless @process.ports.include?(@message.app_port.to_i)
    end

    def validate_web_port!
      return unless @process.type == 'web'

      if @process.ports.nil?
        raise_unvailable_port! unless @message.app_port.to_i == 8080
      else
        raise_unvailable_port! unless @process.ports.include?(@message.app_port.to_i)
      end
    end

    def validate_space!
      raise InvalidRouteMapping.new(INVALID_SPACE_MESSAGE) unless @app.space.guid == @route.space.guid
    end

    def app_event_repository
      Repositories::AppEventRepository.new
    end

    def raise_unvailable_port!
      raise InvalidRouteMapping.new(UNAVAILABLE_APP_PORT_MESSAGE_FORMAT % @message.app_port)
    end
  end
end
