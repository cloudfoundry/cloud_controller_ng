require 'messages/service_route_binding_create_message'
require 'actions/service_route_binding_create'

class ServiceRouteBindingsController < ApplicationController
  def create
    route_services_disabled! unless route_services_enabled?
    message = parse_create_request

    service_instance = fetch_service_instance(message.service_instance_guid)
    route = fetch_route(message.route_guid)

    action = V3::ServiceRouteBindingCreate.new(service_event_repository)
    action.preflight(service_instance, route)

    case service_instance
    when ManagedServiceInstance
      head :not_implemented
    when UserProvidedServiceInstance
      binding = action.create(service_instance, route)
      render status: :created, json: { guid: binding.guid }.to_json
    end
  rescue V3::ServiceRouteBindingCreate::UnprocessableCreate => e
    unprocessable!(e.message)
  rescue V3::ServiceRouteBindingCreate::RouteBindingAlreadyExists
    already_exists!
  end

  private

  def parse_create_request
    message = ServiceRouteBindingCreateMessage.new(hashed_params[:body])
    unprocessable!(message.errors.full_messages) unless message.valid?
    message
  end

  def fetch_service_instance(guid)
    service_instance = VCAP::CloudController::ServiceInstance.first(guid: guid)
    unless service_instance && can_read_space?(service_instance.space)
      service_instance_not_found!(guid)
    end

    unauthorized! unless can_write_space?(service_instance.space)

    service_instance
  end

  def fetch_route(guid)
    route = VCAP::CloudController::Route.first(guid: guid)
    unless route && can_read_space?(route.space)
      route_not_found!(guid)
    end

    route
  end

  def service_event_repository
    VCAP::CloudController::Repositories::ServiceEventRepository::WithUserActor.new(user_audit_info)
  end

  def can_read_space?(space)
    permission_queryer.can_read_from_space?(space.guid, space.organization_guid)
  end

  def can_write_space?(space)
    permission_queryer.can_write_to_space?(space.guid)
  end

  def route_services_enabled?
    VCAP::CloudController::Config.config.get(:route_services_enabled)
  end

  def service_instance_not_found!(guid)
    unprocessable!("The service instance could not be found: #{guid}")
  end

  def route_not_found!(guid)
    unprocessable!("The route could not be found: #{guid}")
  end

  def route_services_disabled!
    unprocessable!('Support for route services is disabled')
  end

  def already_exists!
    raise CloudController::Errors::ApiError.new_from_details('ServiceInstanceAlreadyBoundToSameRoute')
  end
end
