require 'messages/service_route_binding_create_message'
require 'messages/service_route_binding_show_message'
require 'messages/service_route_bindings_list_message'
require 'actions/service_route_binding_create'
require 'actions/service_route_binding_delete'
require 'jobs/v3/create_binding_async_job'
require 'jobs/v3/delete_binding_job'
require 'presenters/v3/paginated_list_presenter'
require 'presenters/v3/service_route_binding_presenter'
require 'fetchers/route_binding_list_fetcher'
require 'decorators/include_binding_service_instance_decorator'
require 'decorators/include_binding_route_decorator'
require 'cloud_controller/paging/sequel_paginator'

class ServiceRouteBindingsController < ApplicationController
  before_action :set_route_binding, except: [:create]

  def index
    message = list_message
    route_bindings = fetch_route_bindings(message)
    render status: :ok, json: Presenters::V3::PaginatedListPresenter.new(
      presenter: Presenters::V3::ServiceRouteBindingPresenter,
      paginated_result: SequelPaginator.new.get_page(route_bindings, message.try(:pagination_options)),
      path: '/v3/service_route_bindings',
      message: message,
      decorators: decorators(message)
    )
  end

  def show
    message = show_message
    route_binding_not_found! unless @route_binding && can_read_from_space?(@route_binding.route.space)
    presenter = Presenters::V3::ServiceRouteBindingPresenter.new(
      @route_binding,
      decorators: decorators(message)
    )
    render status: :ok, json: presenter
  end

  def create
    route_services_disabled! unless route_services_enabled?
    message = parse_create_request

    service_instance = fetch_service_instance(message.service_instance_guid)
    route = fetch_route(message.route_guid)

    check_parameters_support(service_instance, message)
    action = V3::ServiceRouteBindingCreate.new(user_audit_info, message.audit_hash)
    precursor = action.precursor(service_instance, route, message: message)

    case service_instance
    when ManagedServiceInstance
      pollable_job_guid = enqueue_bind_job(precursor.guid, message)
      head :accepted, 'Location' => url_builder.build_url(path: "/v3/jobs/#{pollable_job_guid}")
    when UserProvidedServiceInstance
      action.bind(precursor)
      render status: :created, json: Presenters::V3::ServiceRouteBindingPresenter.new(precursor)
    end
  rescue V3::ServiceRouteBindingCreate::UnprocessableCreate => e
    unprocessable!(e.message)
  rescue V3::ServiceRouteBindingCreate::RouteBindingAlreadyExists
    already_exists!
  end

  def destroy
    route_binding_not_found! unless @route_binding && can_read_from_space?(@route_binding.route.space)
    unauthorized! unless can_bind_in_active_space?(@route_binding.route.space)
    suspended! unless is_space_active?(@route_binding.route.space)

    action = V3::ServiceRouteBindingDelete.new(user_audit_info)
    binding_operation_in_progress! if action.blocking_operation_in_progress?(@route_binding)
    instance_operation_in_progress! if @route_binding.service_instance.operation_in_progress?

    case @route_binding.service_instance
    when ManagedServiceInstance
      pollable_job_guid = enqueue_unbind_job(@route_binding.guid)
      head :accepted, 'Location' => url_builder.build_url(path: "/v3/jobs/#{pollable_job_guid}")
    when UserProvidedServiceInstance
      action.delete(@route_binding)
      head :no_content
    end
  rescue V3::ServiceRouteBindingDelete::UnprocessableDelete => e
    unprocessable!(e.message)
  end

  def parameters
    route_binding_not_found! unless @route_binding && can_read_from_space?(@route_binding.route.space)
    unauthorized! unless can_write_to_active_space?(@route_binding.route.space)
    suspended! unless is_space_active?(@route_binding.route.space)

    fetcher = ServiceBindingRead.new
    parameters = fetcher.fetch_parameters(@route_binding)

    render status: :ok, json: parameters
  rescue ServiceBindingRead::NotSupportedError
    bad_request!('user provided service instances do not support fetching route bindings parameters.') if @route_binding.service_instance.user_provided_instance?
    bad_request!('this service does not support fetching route bindings parameters.')
  rescue LockCheck::ServiceBindingLockedError
    unprocessable!('There is an operation in progress for the service route binding.')
  end

  def update
    route_binding_not_found! unless @route_binding.present? && can_read_from_space?(@route_binding.route.space)
    unauthorized! unless can_write_to_active_space?(@route_binding.route.space)
    suspended! unless is_space_active?(@route_binding.route.space)

    unprocessable!('The service route binding is being deleted') if delete_in_progress?(@route_binding)

    message = MetadataUpdateMessage.new(hashed_params[:body])
    unprocessable!(message.errors.full_messages) unless message.valid?

    updated_route_binding = TransactionalMetadataUpdate.update(@route_binding, message)

    Repositories::ServiceGenericBindingEventRepository.
      new(Repositories::ServiceGenericBindingEventRepository::SERVICE_ROUTE_BINDING).
      record_update(
        @route_binding,
        user_audit_info,
        message.audit_hash
      )

    render status: :ok, json: Presenters::V3::ServiceRouteBindingPresenter.new(updated_route_binding)
  end

  private

  AVAILABLE_DECORATORS = [
    IncludeBindingServiceInstanceDecorator,
    IncludeBindingRouteDecorator
  ].freeze

  def decorators(message)
    AVAILABLE_DECORATORS.select { |d| d.match?(message.include) }
  end

  def list_message
    valid_message(message_type: VCAP::CloudController::ServiceRouteBindingsListMessage)
  end

  def show_message
    valid_message(message_type: VCAP::CloudController::ServiceRouteBindingShowMessage)
  end

  def valid_message(message_type:)
    message_type.from_params(query_params).tap do |message|
      invalid_param!(message.errors.full_messages) unless message.valid?
    end
  end

  def enqueue_bind_job(binding_guid, message)
    bind_job = VCAP::CloudController::V3::CreateBindingAsyncJob.new(
      :route,
      binding_guid,
      user_audit_info: user_audit_info,
      audit_hash: message.audit_hash,
      parameters: message.parameters,
    )
    pollable_job = Jobs::Enqueuer.new(bind_job, queue: Jobs::Queues.generic).enqueue_pollable
    pollable_job.guid
  end

  def enqueue_unbind_job(binding_guid)
    bind_job = VCAP::CloudController::V3::DeleteBindingJob.new(
      :route,
      binding_guid,
      user_audit_info: user_audit_info,
    )
    pollable_job = Jobs::Enqueuer.new(bind_job, queue: Jobs::Queues.generic).enqueue_pollable
    pollable_job.guid
  end

  def fetch_route_bindings(message)
    if permission_queryer.can_read_globally?
      RouteBindingListFetcher.fetch_all(
        message,
        eager_loaded_associations: Presenters::V3::ServiceRouteBindingPresenter.associated_resources,
      )
    else
      RouteBindingListFetcher.fetch_some(
        message,
        space_guids: space_guids,
        eager_loaded_associations: Presenters::V3::ServiceRouteBindingPresenter.associated_resources,
      )
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
    unless service_instance && can_read_from_space?(service_instance.space)
      service_instance_not_found!(guid)
    end

    unauthorized! unless can_bind_in_active_space?(service_instance.space)
    suspended! unless is_space_active?(service_instance.space)

    service_instance
  end

  def fetch_route(guid)
    route = VCAP::CloudController::Route.first(guid: guid)
    unless route && can_read_from_space?(route.space)
      route_not_found!(guid)
    end

    route
  end

  def check_parameters_support(service_instance, message)
    parameters_not_supported! if service_instance.is_a?(VCAP::CloudController::UserProvidedServiceInstance) &&
      message.requested?(:parameters)
  end

  def service_event_repository
    VCAP::CloudController::Repositories::ServiceEventRepository::WithUserActor.new(user_audit_info)
  end

  def can_read_from_space?(space)
    permission_queryer.can_read_from_space?(space.id, space.organization_id)
  end

  def can_bind_in_active_space?(space)
    permission_queryer.can_manage_apps_in_active_space?(space.id)
  end

  def can_write_to_active_space?(space)
    permission_queryer.can_write_to_active_space?(space.id)
  end

  def is_space_active?(space)
    permission_queryer.is_space_active?(space.id)
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

  def instance_operation_in_progress!
    unprocessable!('There is an operation in progress for the service instance.')
  end

  def binding_operation_in_progress!
    unprocessable!('There is an operation in progress for the service binding.')
  end

  def set_route_binding
    @route_binding = RouteBinding.first(guid: hashed_params[:guid])
  end

  def delete_in_progress?(binding)
    binding.operation_in_progress? && binding.last_operation.type == 'delete'
  end
end
