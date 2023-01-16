require 'messages/to_many_relationship_message'
require 'messages/service_instances_list_message'
require 'messages/service_instance_update_managed_message'
require 'messages/service_instance_update_user_provided_message'
require 'messages/service_instance_create_message'
require 'messages/service_instance_create_managed_message'
require 'messages/service_instance_create_user_provided_message'
require 'messages/service_instance_show_message'
require 'messages/shared_spaces_show_message'
require 'presenters/v3/relationship_presenter'
require 'presenters/v3/to_many_relationship_presenter'
require 'presenters/v3/paginated_list_presenter'
require 'presenters/v3/service_instance_presenter'
require 'presenters/v3/shared_spaces_usage_summary_presenter'
require 'actions/service_instance_share'
require 'actions/service_instance_unshare'
require 'actions/service_instance_update_user_provided'
require 'actions/service_instance_create_user_provided'
require 'actions/v3/service_instance_delete'
require 'actions/v3/service_instance_create_managed'
require 'actions/v3/service_instance_update_managed'
require 'actions/service_instance_purge'
require 'fetchers/service_instance_list_fetcher'
require 'decorators/field_service_instance_space_decorator'
require 'decorators/field_service_instance_organization_decorator'
require 'decorators/field_service_instance_offering_decorator'
require 'decorators/field_service_instance_broker_decorator'
require 'controllers/v3/mixins/service_permissions'
require 'decorators/field_service_instance_plan_decorator'
require 'jobs/v3/create_service_instance_job'
require 'jobs/v3/update_service_instance_job'

class ServiceInstancesV3Controller < ApplicationController
  include ServicePermissions

  def index
    message = ServiceInstancesListMessage.from_params(query_params)
    invalid_param!(message.errors.full_messages) unless message.valid?

    dataset = if permission_queryer.can_read_globally?
                ServiceInstanceListFetcher.fetch(
                  message,
                  eager_loaded_associations: Presenters::V3::ServiceInstancePresenter.associated_resources,
                  omniscient: true,
                )
              else
                ServiceInstanceListFetcher.fetch(
                  message,
                  eager_loaded_associations: Presenters::V3::ServiceInstancePresenter.associated_resources,
                  readable_spaces_dataset: permission_queryer.readable_space_guids_query,
                )
              end

    render status: :ok, json: Presenters::V3::PaginatedListPresenter.new(
      presenter: Presenters::V3::ServiceInstancePresenter,
      paginated_result: SequelPaginator.new.get_page(dataset, message.try(:pagination_options)),
      path: '/v3/service_instances',
      message: message,
      decorators: decorators_for_fields(message.fields)
    )
  end

  def show
    service_instance = ServiceInstance.first(guid: hashed_params[:guid])
    service_instance_not_found! unless service_instance && can_read_service_instance?(service_instance)

    message = ServiceInstanceShowMessage.from_params(query_params)
    invalid_param!(message.errors.full_messages) unless message.valid?

    presenter = Presenters::V3::ServiceInstancePresenter.new(
      service_instance,
      decorators: decorators_for_fields(message.fields)
    )

    render status: :ok, json: presenter.to_json
  end

  def create
    FeatureFlag.raise_unless_enabled!(:service_instance_creation) unless admin?

    message = build_create_message(hashed_params[:body])

    space = Space.first(guid: message.space_guid)
    unprocessable_space! unless space && can_read_from_space?(space)
    unauthorized! unless can_write_to_active_space?(space)
    suspended! unless is_space_active?(space)

    case message.type
    when 'user-provided'
      create_user_provided(message)
    when 'managed'
      create_managed(message, space: space)
    end
  end

  def update
    service_instance = fetch_writable_service_instance(hashed_params[:guid])

    case service_instance
    when ManagedServiceInstance
      update_managed(service_instance)
    when UserProvidedServiceInstance
      update_user_provided(service_instance)
    end
  end

  def destroy
    service_instance = fetch_writable_service_instance(hashed_params[:guid])
    purge = params['purge'] == 'true'

    if purge
      unauthorized! unless service_instance.is_a?(UserProvidedServiceInstance) || current_user_can_write?(service_instance.service)
      ServiceInstancePurge.new(service_event_repository).purge(service_instance)
      return [:no_content, nil]
    end

    delete_action = V3::ServiceInstanceDelete.new(service_instance, service_event_repository)
    operation_in_progress! if delete_action.blocking_operation_in_progress?

    case service_instance
    when VCAP::CloudController::ManagedServiceInstance
      job_guid = enqueue_delete_job(service_instance)
      head :accepted, 'Location' => url_builder.build_url(path: "/v3/jobs/#{job_guid}")
    when VCAP::CloudController::UserProvidedServiceInstance
      delete_action.delete
      head :no_content
    end
  end

  def share_service_instance
    FeatureFlag.raise_unless_enabled!(:service_instance_sharing)

    service_instance = ServiceInstance.first(guid: hashed_params[:guid])
    resource_not_found!(:service_instance) unless service_instance && can_read_service_instance?(service_instance)
    unauthorized! unless can_write_to_active_space?(service_instance.space)
    suspended! unless is_space_active?(service_instance.space)

    message = VCAP::CloudController::ToManyRelationshipMessage.new(hashed_params[:body])
    unprocessable!(message.errors.full_messages) unless message.valid?

    target_spaces = Space.where(guid: message.guids)
    check_spaces_exist_and_are_writeable!(service_instance, message.guids, target_spaces)

    share = ServiceInstanceShare.new
    share.create(service_instance, target_spaces, user_audit_info)

    render status: :ok, json: Presenters::V3::ToManyRelationshipPresenter.new(
      "service_instances/#{service_instance.guid}", service_instance.shared_spaces, 'shared_spaces', build_related: false)
  rescue VCAP::CloudController::ServiceInstanceShare::Error => e
    unprocessable!(e.message)
  end

  def unshare_service_instance
    service_instance = ServiceInstance.first(guid: hashed_params[:guid])

    resource_not_found!(:service_instance) unless service_instance && can_read_service_instance?(service_instance)
    unauthorized! unless can_write_to_active_space?(service_instance.space)
    suspended! unless is_space_active?(service_instance.space)

    space_guid = hashed_params[:space_guid]
    target_space = Space.first(guid: space_guid)

    unless target_space
      unprocessable!("Unable to unshare service instance from space #{space_guid}. Ensure the space exists.")
    end

    unshare = ServiceInstanceUnshare.new
    unshare.unshare(service_instance, target_space, user_audit_info)

    head :no_content
  rescue VCAP::CloudController::ServiceInstanceUnshare::Error => e
    raise CloudController::Errors::ApiError.new_from_details('ServiceInstanceUnshareFailed', e.message)
  end

  def relationships_shared_spaces
    service_instance = ServiceInstance.first(guid: hashed_params[:guid])
    resource_not_found!(:service_instance) unless service_instance && can_read_from_space?(service_instance.space)

    message = SharedSpacesShowMessage.from_params(query_params)
    invalid_param!(message.errors.full_messages) unless message.valid?

    render status: :ok, json: Presenters::V3::ToManyRelationshipPresenter.new(
      "service_instances/#{service_instance.guid}",
      service_instance.shared_spaces,
      'shared_spaces',
      build_related: false,
      decorators: decorators_for_fields(message.fields)
    )
  end

  def shared_spaces_usage_summary
    service_instance = ServiceInstance.first(guid: hashed_params[:guid])
    service_instance_not_found! unless service_instance.present? && can_read_from_space?(service_instance.space)

    render status: :ok, json: Presenters::V3::SharedSpacesUsageSummaryPresenter.new(service_instance)
  end

  def credentials
    service_instance = UserProvidedServiceInstance.first(guid: hashed_params[:guid])
    service_instance_not_found! unless service_instance && can_read_service_instance?(service_instance)
    unauthorized! unless permission_queryer.can_read_secrets_in_space?(service_instance.space_id, service_instance.space.organization_id)

    render status: :ok, json: (service_instance.credentials || {})
  end

  def parameters
    service_instance = ServiceInstance.first(guid: hashed_params[:guid])
    service_instance_not_found! unless service_instance && can_read_service_instance?(service_instance)
    unauthorized! unless can_read_from_space?(service_instance.space)

    service_instance_not_found! if service_instance.managed_instance? && service_instance.create_failed?

    begin
      render status: :ok, json: ServiceInstanceRead.new.fetch_parameters(service_instance)
    rescue ServiceInstanceRead::NotSupportedError
      raise CloudController::Errors::ApiError.new_from_details('ServiceFetchInstanceParametersNotSupported')
    end
  end

  def show_permissions
    service_instance = ServiceInstance.first(guid: hashed_params[:guid])
    service_instance_not_found! unless service_instance

    render status: :ok, json: {
      manage: is_space_active?(service_instance.space) ? can_write_to_active_space?(service_instance.space) : admin?,
      read: can_read_service_instance?(service_instance),
    }
  end

  private

  DECORATORS = [
    FieldServiceInstanceSpaceDecorator,
    FieldServiceInstanceOrganizationDecorator,
    FieldServiceInstancePlanDecorator,
    FieldServiceInstanceOfferingDecorator,
    FieldServiceInstanceBrokerDecorator
  ].freeze

  def decorators_for_fields(fields)
    DECORATORS.
      select { |decorator| decorator.match?(fields) }.
      map { |decorator| decorator.new(fields) }
  end

  def create_user_provided(message)
    instance = ServiceInstanceCreateUserProvided.new(service_event_repository).create(message)

    render status: :created, json: Presenters::V3::ServiceInstancePresenter.new(instance)
  rescue ServiceInstanceCreateUserProvided::InvalidUserProvidedServiceInstance => e
    unprocessable!(e.message)
  end

  def create_managed(message, space:)
    service_plan = ServicePlan.first(guid: message.service_plan_guid)
    unprocessable_service_plan! unless service_plan_valid?(service_plan, space)

    action = V3::ServiceInstanceCreateManaged.new(user_audit_info, message.audit_hash)
    instance = action.precursor(message: message, service_plan: service_plan)

    provision_job = VCAP::CloudController::V3::CreateServiceInstanceJob.new(
      instance.guid,
      arbitrary_parameters: message.parameters,
      user_audit_info: user_audit_info,
      audit_hash: message.audit_hash
    )
    pollable_job = Jobs::Enqueuer.new(provision_job, queue: Jobs::Queues.generic).enqueue_pollable

    head :accepted, 'Location' => url_builder.build_url(path: "/v3/jobs/#{pollable_job.guid}")
  rescue VCAP::CloudController::ServiceInstanceCreateMixin::UnprocessableOperation,
         V3::ServiceInstanceCreateManaged::InvalidManagedServiceInstance => e
    unprocessable!(e.message)
  end

  def update_user_provided(service_instance)
    message = ServiceInstanceUpdateUserProvidedMessage.new(hashed_params[:body])
    unprocessable!(message.errors.full_messages) unless message.valid?

    service_instance = ServiceInstanceUpdateUserProvided.new(service_event_repository).update(service_instance, message)
    render status: :ok, json: Presenters::V3::ServiceInstancePresenter.new(service_instance)
  rescue ServiceInstanceUpdateUserProvided::UnprocessableUpdate => api_err
    unprocessable!(api_err.message)
  end

  def update_managed(service_instance)
    message = ServiceInstanceUpdateManagedMessage.new(hashed_params[:body])
    unprocessable!(message.errors.full_messages) unless message.valid?
    raise_if_invalid_service_plan!(service_instance, message)

    action = V3::ServiceInstanceUpdateManaged.new(service_instance, message, user_audit_info, message.audit_hash)
    action.preflight!
    if action.update_broker_needed?
      update_job = action.enqueue_update
      head :accepted, 'Location' => url_builder.build_url(path: "/v3/jobs/#{update_job.guid}")
    else
      service_instance = action.update_sync
      render status: :ok, json: Presenters::V3::ServiceInstancePresenter.new(service_instance)
    end
  rescue V3::ServiceInstanceUpdateManaged::UnprocessableUpdate => api_err
    unprocessable!(api_err.message)
  rescue LockCheck::ServiceBindingLockedError => e
    raise CloudController::Errors::ApiError.new_from_details('AsyncServiceBindingOperationInProgress', e.service_binding.app.name, e.service_binding.service_instance.name)
  end

  def check_spaces_exist_and_are_writeable!(service_instance, request_guids, found_spaces)
    unreadable_spaces = found_spaces.reject { |s| can_read_from_space?(s) }
    unwriteable_spaces = found_spaces.reject { |s| can_write_to_active_space?(s) && is_space_active?(s) || unreadable_spaces.include?(s) }

    not_found_space_guids = request_guids - found_spaces.map(&:guid)
    unreadable_space_guids = not_found_space_guids + unreadable_spaces.map(&:guid)
    unwriteable_space_guids = unwriteable_spaces.map(&:guid)

    if unreadable_space_guids.any? || unwriteable_space_guids.any?
      unreadable_error = unreadable_error_message(service_instance.name, unreadable_space_guids)
      unwriteable_error = unwriteable_error_message(service_instance.name, unwriteable_space_guids)

      error_msg = [unreadable_error, unwriteable_error].map(&:presence).compact.join("\n")

      unprocessable!(error_msg)
    end
  end

  def build_create_message(params)
    generic_message = ServiceInstanceCreateMessage.new(params)
    unprocessable!(generic_message.errors.full_messages) unless generic_message.valid?

    specific_message = if generic_message.type == 'managed'
                         ServiceInstanceCreateManagedMessage.new(params)
                       else
                         ServiceInstanceCreateUserProvidedMessage.new(params)
                       end

    unprocessable!(specific_message.errors.full_messages) unless specific_message.valid?
    specific_message
  end

  def fetch_writable_service_instance(guid)
    service_instance = ServiceInstance.first(guid: guid)
    service_instance_not_found! unless service_instance && can_read_service_instance?(service_instance)
    unauthorized! unless can_write_to_active_space?(service_instance.space)
    suspended! unless is_space_active?(service_instance.space)

    service_instance
  end

  def enqueue_delete_job(service_instance)
    delete_job = V3::DeleteServiceInstanceJob.new(service_instance.guid, user_audit_info)
    pollable_job = Jobs::Enqueuer.new(delete_job, queue: Jobs::Queues.generic).enqueue_pollable
    pollable_job.guid
  end

  def unreadable_error_message(service_instance_name, unreadable_space_guids)
    if unreadable_space_guids.any?
      unreadable_guid_list = unreadable_space_guids.map { |g| "'#{g}'" }.join(', ')

      "Unable to share service instance #{service_instance_name} with spaces [#{unreadable_guid_list}]. Ensure the spaces exist and that you have access to them."
    end
  end

  def unwriteable_error_message(service_instance_name, unwriteable_space_guids)
    if unwriteable_space_guids.any?
      unwriteable_guid_list = unwriteable_space_guids.map { |s| "'#{s}'" }.join(', ')

      "Unable to share service instance #{service_instance_name} with spaces [#{unwriteable_guid_list}]. "\
      'Write permission is required in order to share a service instance with a space.'
    end
  end

  def can_read_service_instance?(service_instance)
    readable_spaces = service_instance.shared_spaces + [service_instance.space]

    readable_spaces.any? do |space|
      permission_queryer.can_read_from_space?(space.id, space.organization_id)
    end
  end

  def can_read_from_space?(space)
    permission_queryer.can_read_from_space?(space.id, space.organization_id)
  end

  def can_write_to_active_space?(space)
    permission_queryer.can_write_to_active_space?(space.id)
  end

  def is_space_active?(space)
    permission_queryer.is_space_active?(space.id)
  end

  def admin?
    permission_queryer.can_write_globally?
  end

  def service_plan_valid?(service_plan, space)
    service_plan &&
      visible_to_current_user?(plan: service_plan) &&
      service_plan.visible_in_space?(space)
  end

  def raise_if_invalid_service_plan!(service_instance, message)
    if message.service_plan_guid
      service_plan = ServicePlan.first(guid: message.service_plan_guid)
      unprocessable_service_plan! unless service_plan_valid?(service_plan, service_instance.space)
      invalid_service_plan_relation! unless service_plan.service == service_instance.service
    end
  end

  def service_event_repository
    VCAP::CloudController::Repositories::ServiceEventRepository.new(user_audit_info)
  end

  def service_instance_not_found!
    resource_not_found!(:service_instance)
  end

  def unprocessable_space!
    unprocessable!('Invalid space. Ensure that the space exists and you have access to it.')
  end

  def unprocessable_service_plan!
    unprocessable!('Invalid service plan. Ensure that the service plan exists, is available, and you have access to it.')
  end

  def invalid_service_plan_relation!
    raise CloudController::Errors::ApiError.new_from_details('InvalidRelation', 'service plan relates to a different service offering')
  end

  def operation_in_progress!
    unprocessable!('There is an operation in progress for the service instance.')
  end

  def read_scope
    %w(show_permissions).include?(action_name) && roles.cloud_controller_service_permissions_reader? ? true : super
  end
end
