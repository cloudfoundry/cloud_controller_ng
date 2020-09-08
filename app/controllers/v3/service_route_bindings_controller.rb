require 'messages/service_route_binding_create_message'
require 'messages/service_route_bindings_list_message'
require 'actions/service_route_binding_create'
require 'jobs/v3/create_route_binding_job'
require 'presenters/v3/service_route_binding_presenter'
require 'fetchers/route_binding_list_fetcher'

class ServiceRouteBindingsController < ApplicationController
  def create
    route_services_disabled! unless route_services_enabled?
    message = parse_create_request

    service_instance = fetch_service_instance(message.service_instance_guid)
    route = fetch_route(message.route_guid)

    check_parameters_support(service_instance, message)
    action = V3::ServiceRouteBindingCreate.new(service_event_repository)
    precursor = action.precursor(service_instance, route)

    case service_instance
    when ManagedServiceInstance
      bind_job = VCAP::CloudController::V3::CreateRouteBindingJob.new(
        precursor.guid,
        user_audit_info: user_audit_info,
        parameters: message.parameters,
      )
      pollable_job = Jobs::Enqueuer.new(bind_job, queue: Jobs::Queues.generic).enqueue_pollable
      head :accepted, 'Location' => url_builder.build_url(path: "/v3/jobs/#{pollable_job.guid}")
    when UserProvidedServiceInstance
      action.bind(precursor)
      render status: :created, json: Presenters::V3::ServiceRouteBindingPresenter.new(precursor)
    end
  rescue V3::ServiceRouteBindingCreate::UnprocessableCreate => e
    unprocessable!(e.message)
  rescue V3::ServiceRouteBindingCreate::RouteBindingAlreadyExists
    already_exists!
  end

  def show
    route_binding = RouteBinding.first(guid: hashed_params[:guid])
    route_binding_not_found! unless route_binding && can_read_space?(route_binding.route.space)
    render status: :ok, json: Presenters::V3::ServiceRouteBindingPresenter.new(route_binding)
  end

  def index
    message = VCAP::CloudController::ServiceRouteBindingsListMessage.from_params(query_params)
    route_bindings = fetch_route_bindings(message)
    render status: :ok, json: Presenters::V3::PaginatedListPresenter.new(
      presenter: Presenters::V3::ServiceRouteBindingPresenter,
      paginated_result: SequelPaginator.new.get_page(route_bindings, message.try(:pagination_options)),
      path: '/v3/service_route_bindings',
      message: message,
      decorators: decorators(message)
    )
  end

  private

  AVAILABLE_DECORATORS = [
    IncludeBindingServiceInstanceDecorator
  ].freeze

  def decorators(message)
    AVAILABLE_DECORATORS.select { |d| d.match?(message.include) }
  end

  def fetch_route_bindings(message)
    fetcher = RouteBindingListFetcher.new
    if permission_queryer.can_read_globally?
      fetcher.fetch_all(message)
    else
      fetcher.fetch_some(message, space_guids: space_guids)
    end
  end

  def space_guids
    permission_queryer.readable_space_guids
  end

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

  def check_parameters_support(service_instance, message)
    unless service_instance.is_a?(VCAP::CloudController::ManagedServiceInstance)
      parameters_not_supported! if message.requested?(:parameters)
    end
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

  def route_binding_not_found!
    resource_not_found!(:service_route_binding)
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

  def parameters_not_supported!
    unprocessable!('Binding parameters are not supported for user-provided service instances')
  end

  def already_exists!
    raise CloudController::Errors::ApiError.new_from_details('ServiceInstanceAlreadyBoundToSameRoute').with_response_code(422)
  end
end
