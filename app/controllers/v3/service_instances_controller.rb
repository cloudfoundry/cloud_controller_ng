require 'messages/to_many_relationship_message'
require 'messages/service_instances_list_message'
require 'messages/service_instance_update_managed_message'
require 'messages/service_instance_update_user_provided_message'
require 'messages/service_instance_create_message'
require 'messages/service_instance_create_managed_message'
require 'messages/service_instance_create_user_provided_message'
require 'messages/service_instance_show_message'
require 'presenters/v3/relationship_presenter'
require 'presenters/v3/to_many_relationship_presenter'
require 'presenters/v3/paginated_list_presenter'
require 'presenters/v3/service_instance_presenter'
require 'actions/service_instance_share'
require 'actions/service_instance_unshare'
require 'actions/service_instance_update_managed'
require 'actions/service_instance_update_user_provided'
require 'actions/service_instance_create_user_provided'
require 'actions/v3/service_instance_delete'
require 'actions/service_instance_create_managed'
require 'fetchers/service_instance_list_fetcher'
require 'decorators/field_service_instance_space_decorator'
require 'decorators/field_service_instance_organization_decorator'
require 'decorators/field_service_instance_offering_decorator'
require 'decorators/field_service_instance_broker_decorator'
require 'controllers/v3/mixins/service_permissions'
require 'decorators/field_service_instance_plan_decorator'

class ServiceInstancesV3Controller < ApplicationController
  include ServicePermissions

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

  def index
    message = ServiceInstancesListMessage.from_params(query_params)
    invalid_param!(message.errors.full_messages) unless message.valid?

    dataset = if permission_queryer.can_read_globally?
                ServiceInstanceListFetcher.new.fetch(message, omniscient: true)
              else
                ServiceInstanceListFetcher.new.fetch(message, readable_space_guids: permission_queryer.readable_space_guids)
              end

    render status: :ok, json: Presenters::V3::PaginatedListPresenter.new(
      presenter: Presenters::V3::ServiceInstancePresenter,
      paginated_result: SequelPaginator.new.get_page(dataset, message.try(:pagination_options)),
      path: '/v3/service_instances',
      message: message,
      decorators: decorators_for_fields(message.fields)
    )
  end

  def create
    FeatureFlag.raise_unless_enabled!(:service_instance_creation) unless admin?

    message = build_create_message(hashed_params[:body])

    space = Space.first(guid: message.space_guid)
    unprocessable_space! unless space && can_read_space?(space)
    unauthorized! if space&.in_suspended_org? && !admin?
    unauthorized! unless can_write_space?(space)

    case message.type
    when 'user-provided'
      create_user_provided(message)
    when 'managed'
      create_managed(message, space: space)
    end
  end

  def update
    service_instance = ServiceInstance.first(guid: hashed_params[:guid])
    resource_not_found!(:service_instance) unless service_instance && can_read_service_instance?(service_instance)
    unauthorized! unless can_write_space?(service_instance.space)

    case service_instance
    when ManagedServiceInstance
      update_managed(service_instance)
    when UserProvidedServiceInstance
      update_user_provided(service_instance)
    end
  end

  def destroy
    service_instance = ServiceInstance.first(guid: hashed_params[:guid])
    service_instance_not_found! unless service_instance && can_read_service_instance?(service_instance)

    unauthorized! unless can_write_space?(service_instance.space)

    service_event_repository = VCAP::CloudController::Repositories::ServiceEventRepository.new(user_audit_info)
    job_guid = V3::ServiceInstanceDelete.new(service_event_repository).delete(service_instance)

    if job_guid.blank?
      head :no_content
    else
      head :accepted, 'Location' => url_builder.build_url(path: "/v3/jobs/#{job_guid}")
    end
  rescue V3::ServiceInstanceDelete::AssociationNotEmptyError
    associations_not_empty!
  rescue V3::ServiceInstanceDelete::InstanceSharedError
    cannot_delete_shared_instances!(service_instance.name)
  end

  def share_service_instance
    FeatureFlag.raise_unless_enabled!(:service_instance_sharing)

    service_instance = ServiceInstance.first(guid: hashed_params[:service_instance_guid])

    resource_not_found!(:service_instance) unless service_instance && can_read_service_instance?(service_instance)
    unauthorized! unless can_write_space?(service_instance.space)

    message = VCAP::CloudController::ToManyRelationshipMessage.new(hashed_params[:body])
    unprocessable!(message.errors.full_messages) unless message.valid?

    spaces = Space.where(guid: message.guids)
    check_spaces_exist_and_are_writeable!(service_instance, message.guids, spaces)

    share = ServiceInstanceShare.new
    share.create(service_instance, spaces, user_audit_info)

    render status: :ok, json: Presenters::V3::ToManyRelationshipPresenter.new(
      "service_instances/#{service_instance.guid}", service_instance.shared_spaces, 'shared_spaces', build_related: false)
  rescue VCAP::CloudController::ServiceInstanceShare::Error => e
    unprocessable!(e.message)
  end

  def unshare_service_instance
    service_instance = ServiceInstance.first(guid: hashed_params[:service_instance_guid])

    resource_not_found!(:service_instance) unless service_instance && can_read_service_instance?(service_instance)
    unauthorized! unless can_write_space?(service_instance.space)

    space_guid = hashed_params[:space_guid]
    target_space = Space.first(guid: space_guid)

    unless target_space && service_instance.shared_spaces.include?(target_space)
      unprocessable!("Unable to unshare service instance from space #{space_guid}. Ensure the space exists and the service instance has been shared to this space.")
    end

    unshare = ServiceInstanceUnshare.new
    unshare.unshare(service_instance, target_space, user_audit_info)

    head :no_content
  rescue VCAP::CloudController::ServiceInstanceUnshare::Error => e
    raise CloudController::Errors::ApiError.new_from_details('ServiceInstanceUnshareFailed', e.message)
  end

  def relationships_shared_spaces
    service_instance = ServiceInstance.first(guid: hashed_params[:service_instance_guid])
    resource_not_found!(:service_instance) unless service_instance && can_read_space?(service_instance.space)

    render status: :ok, json: Presenters::V3::ToManyRelationshipPresenter.new(
      "service_instances/#{service_instance.guid}", service_instance.shared_spaces, 'shared_spaces', build_related: false)
  end

  def credentials
    service_instance = UserProvidedServiceInstance.first(guid: hashed_params[:guid])
    service_instance_not_found! unless service_instance && can_read_service_instance?(service_instance)
    unauthorized! unless permission_queryer.can_read_secrets_in_space?(service_instance.space.guid, service_instance.space.organization_guid)

    render status: :ok, json: (service_instance.credentials || {})
  end

  def parameters
    service_instance = ManagedServiceInstance.first(guid: hashed_params[:guid])
    service_instance_not_found! unless service_instance && can_read_service_instance?(service_instance)
    unauthorized! unless can_read_space?(service_instance.space)

    begin
      render status: :ok, json: ServiceInstanceRead.new.fetch_parameters(service_instance)
    rescue ServiceInstanceRead::NotSupportedError
      raise CloudController::Errors::ApiError.new_from_details('ServiceFetchInstanceParametersNotSupported')
    end
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
    service_event_repository = VCAP::CloudController::Repositories::ServiceEventRepository::WithUserActor.new(user_audit_info)

    instance = ServiceInstanceCreateUserProvided.new(service_event_repository).create(message)

    render status: :created, json: Presenters::V3::ServiceInstancePresenter.new(instance)
  rescue ServiceInstanceCreateUserProvided::InvalidUserProvidedServiceInstance => e
    unprocessable!(e.message)
  end

  def create_managed(message, space:)
    service_event_repository = VCAP::CloudController::Repositories::ServiceEventRepository.new(user_audit_info)
    service_plan = ServicePlan.first(guid: message.service_plan_guid)
    unprocessable_service_plan! unless service_plan_valid?(service_plan, space)

    broker_unavailable! unless service_plan.service_broker.available?

    job = ServiceInstanceCreateManaged.new(service_event_repository).create(message)

    head :accepted, 'Location' => url_builder.build_url(path: "/v3/jobs/#{job.guid}")
  rescue ServiceInstanceCreateManaged::UnprocessableCreate => e
    unprocessable!(e.message)
  rescue ServiceInstanceCreateManaged::InvalidManagedServiceInstance => e
    unprocessable!(e.message)
  end

  def update_user_provided(service_instance)
    message = ServiceInstanceUpdateUserProvidedMessage.new(hashed_params[:body])
    unprocessable!(message.errors.full_messages) unless message.valid?

    service_event_repository = VCAP::CloudController::Repositories::ServiceEventRepository::WithUserActor.new(user_audit_info)
    service_instance = ServiceInstanceUpdateUserProvided.new(service_event_repository).update(service_instance, message)
    render status: :ok, json: Presenters::V3::ServiceInstancePresenter.new(service_instance)
  rescue ServiceInstanceUpdateUserProvided::UnprocessableUpdate => api_err
    unprocessable!(api_err.message)
  end

  def update_managed(service_instance)
    message = ServiceInstanceUpdateManagedMessage.new(hashed_params[:body])
    unprocessable!(message.errors.full_messages) unless message.valid?

    if message.service_plan_guid
      service_plan = ServicePlan.first(guid: message.service_plan_guid)
      unprocessable_service_plan! unless service_plan_valid?(service_plan, service_instance.space)
      invalid_service_plan_relation! unless service_plan.service == service_instance.service
    end

    service_event_repository = VCAP::CloudController::Repositories::ServiceEventRepository.new(user_audit_info)
    service_instance, job = ServiceInstanceUpdateManaged.new(service_event_repository).update(service_instance, message)

    if job.nil?
      render status: :ok, json: Presenters::V3::ServiceInstancePresenter.new(service_instance)
    else
      head :accepted, 'Location' => url_builder.build_url(path: "/v3/jobs/#{job.guid}")
    end
  rescue ServiceInstanceUpdateManaged::UnprocessableUpdate => api_err
    unprocessable!(api_err.message)
  end

  def admin?
    permission_queryer.can_write_globally?
  end

  def check_spaces_exist_and_are_writeable!(service_instance, request_guids, found_spaces)
    unreadable_spaces = found_spaces.reject { |s| can_read_space?(s) }
    unwriteable_spaces = found_spaces.reject { |s| can_write_space?(s) || unreadable_spaces.include?(s) }

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
      permission_queryer.can_read_from_space?(space.guid, space.organization_guid)
    end
  end

  def can_read_space?(space)
    permission_queryer.can_read_from_space?(space.guid, space.organization_guid)
  end

  def can_write_space?(space)
    permission_queryer.can_write_to_space?(space.guid)
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

  def service_instance_not_found!
    resource_not_found!(:service_instance)
  end

  def service_plan_valid?(service_plan, space)
    service_plan &&
      visible_to_current_user?(plan: service_plan) &&
      service_plan.visible_in_space?(space)
  end

  def unprocessable_space!
    unprocessable!('Invalid space. Ensure that the space exists and you have access to it.')
  end

  def unprocessable_service_plan!
    unprocessable!('Invalid service plan. Ensure that the service plan exists, is available, and you have access to it.')
  end

  def broker_unavailable!
    unprocessable!('The service instance cannot be created because there is an operation in progress for the service broker')
  end

  def invalid_service_plan_relation!
    raise CloudController::Errors::ApiError.new_from_details('InvalidRelation', 'service plan relates to a different service offering')
  end

  def associations_not_empty!
    associations = 'service_bindings, service_keys, and routes'
    raise CloudController::Errors::ApiError.
      new_from_details('AssociationNotEmpty', associations, :service_instances).
      with_response_code(422)
  end

  def cannot_delete_shared_instances!(name)
    raise CloudController::Errors::ApiError.new_from_details('ServiceInstanceDeletionSharesExists', name)
  end
end
