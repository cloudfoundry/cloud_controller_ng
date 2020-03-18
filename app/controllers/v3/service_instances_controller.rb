require 'messages/to_many_relationship_message'
require 'messages/service_instances_list_message'
require 'messages/service_instance_update_message'
require 'messages/service_instance_create_message'
require 'presenters/v3/relationship_presenter'
require 'presenters/v3/to_many_relationship_presenter'
require 'presenters/v3/paginated_list_presenter'
require 'presenters/v3/service_instance_presenter'
require 'actions/service_instance_share'
require 'actions/service_instance_unshare'
require 'actions/service_instance_update'
require 'fetchers/service_instance_list_fetcher'

class ServiceInstancesV3Controller < ApplicationController
  def show
    service_instance = ServiceInstance.first(guid: hashed_params[:guid])
    service_instance_not_found! unless service_instance && can_read_service_instance?(service_instance)

    presenter = Presenters::V3::ServiceInstancePresenter.new(service_instance)
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
      message: message
    )
  end

  def create
    FeatureFlag.raise_unless_enabled!(:service_instance_creation) unless admin?

    message = ServiceInstanceCreateMessage.new(hashed_params[:body])
    invalid_param!(message.errors.full_messages) unless message.valid?

    space = Space.where(guid: message.space_guid).first
    unauthorized! if space&.in_suspended_org? && !admin?

    render status: :ok, json: '{}'
  end

  def update
    message = ServiceInstanceUpdateMessage.new(hashed_params[:body])
    unprocessable!(message.errors.full_messages) unless message.valid?

    service_instance = ServiceInstance.first(guid: hashed_params[:guid])
    resource_not_found!(:service_instance) unless service_instance && can_read_service_instance?(service_instance)
    unauthorized! unless can_write_space?(service_instance.space)

    service_instance = ServiceInstanceUpdate.update(service_instance, message)

    render status: :ok, json: Presenters::V3::ServiceInstancePresenter.new(service_instance)
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
    unauthorized! unless permission_queryer.can_read_secrets_in_space?(service_instance.space.guid, service_instance.space.organization.guid)

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
    permission_queryer.can_read_from_space?(space.guid, space.organization.guid)
  end

  def can_write_space?(space)
    permission_queryer.can_write_to_space?(space.guid)
  end

  def service_instance_not_found!
    resource_not_found!(:service_instance)
  end
end
