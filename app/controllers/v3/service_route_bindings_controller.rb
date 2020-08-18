require 'messages/service_route_binding_create_message'

class ServiceRouteBindingsController < ApplicationController
  def create
    message = parse_request

    service_instance = fetch_service_instance(message.service_instance_guid)
    route = fetch_route(message.route_guid)
    check_space(service_instance, route)

    head :not_implemented
  end

  private

  def parse_request
    message = ServiceRouteBindingCreateMessage.new(hashed_params[:body])
    unprocessable!(message.errors.full_messages) unless message.valid?
    message
  end

  def fetch_service_instance(guid)
    service_instance = VCAP::CloudController::ServiceInstance.first(guid: guid)
    unless service_instance && can_read_space?(service_instance.space)
      unprocessable_service_instance!(guid)
    end
    service_instance
  end

  def fetch_route(guid)
    route = VCAP::CloudController::Route.first(guid: guid)
    unless route && can_read_space?(route.space)
      unprocessable_route!(guid)
    end
    route
  end

  def check_space(service_instance, route)
    space = service_instance.space
    space_mismatch! unless space == route.space
    unauthorized! unless can_write_space?(space)
  end

  def can_read_space?(space)
    permission_queryer.can_read_from_space?(space.guid, space.organization_guid)
  end

  def can_write_space?(space)
    permission_queryer.can_write_to_space?(space.guid)
  end

  def unprocessable_service_instance!(guid)
    unprocessable!("The service instance could not be found: #{guid}")
  end

  def unprocessable_route!(guid)
    unprocessable!("The route could not be found: #{guid}")
  end

  def space_mismatch!
    unprocessable!('The service instance and the route are in different spaces.')
  end
end
