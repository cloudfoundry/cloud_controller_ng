require 'messages/to_many_relationship_message'
require 'messages/service_instances/service_instances_list_message'

require 'presenters/v3/relationship_presenter'
require 'presenters/v3/to_many_relationship_presenter'
require 'presenters/v3/paginated_list_presenter'
require 'actions/service_instance_share'
require 'actions/service_instance_unshare'
require 'fetchers/managed_service_instance_list_fetcher'

class ServiceInstancesV3Controller < ApplicationController
  def index
    message = ServiceInstancesListMessage.from_params(query_params)
    invalid_param!(message.errors.full_messages) unless message.valid?

    dataset = if can_read_globally?
                ManagedServiceInstanceListFetcher.new.fetch_all(message: message)
              else
                ManagedServiceInstanceListFetcher.new.fetch(message: message, readable_space_guids: readable_space_guids)
              end

    render status: :ok, json: Presenters::V3::PaginatedListPresenter.new(
      dataset: dataset,
      path: '/v3/service_instances',
      message: message)
  end

  def share_service_instance
    FeatureFlag.raise_unless_enabled!(:service_instance_sharing)

    service_instance = ServiceInstance.first(guid: params[:service_instance_guid])

    resource_not_found!(:service_instance) unless service_instance && can_read_service_instance?(service_instance)
    unauthorized! unless can_write_space?(service_instance.space)

    message = VCAP::CloudController::ToManyRelationshipMessage.create_from_http_request(params[:body])
    unprocessable!(message.errors.full_messages) unless message.valid?

    spaces = Space.where(guid: message.guids)
    check_spaces_exist_and_are_readable!(message.guids, spaces)
    check_spaces_are_writeable!(spaces)

    share = ServiceInstanceShare.new
    share.create(service_instance, spaces, user_audit_info)

    render status: :ok, json: Presenters::V3::ToManyRelationshipPresenter.new(
      "service_instances/#{service_instance.guid}", service_instance.shared_spaces, 'shared_spaces')
  end

  def unshare_service_instance
    FeatureFlag.raise_unless_enabled!(:service_instance_sharing)

    service_instance = ServiceInstance.first(guid: params[:service_instance_guid])

    resource_not_found!(:service_instance) unless service_instance && can_read_service_instance?(service_instance)
    unauthorized! unless can_write_space?(service_instance.space)

    space_guid = params[:space_guid]
    target_space = Space.first(guid: space_guid)

    unless target_space && service_instance.shared_spaces.include?(target_space)
      unprocessable!("Unable to unshare service instance from space #{space_guid}. Ensure the space exists and the service instance has been shared to this space.")
    end

    unshare = ServiceInstanceUnshare.new
    unshare.unshare(service_instance, target_space, user_audit_info)

    head :no_content
  end

  private

  def check_spaces_are_writeable!(spaces)
    unwriteable_spaces = spaces.reject do |space|
      can_write?(space.guid)
    end

    unauthorized! unless unwriteable_spaces.empty?
  end

  def check_spaces_exist_and_are_readable!(request_guids, found_spaces)
    missing_guids = request_guids - found_spaces.map(&:guid)

    unreadable_spaces = found_spaces.reject do |space|
      can_read_space?(space)
    end

    missing_guids += unreadable_spaces.map(&:guid)

    unless missing_guids.empty?
      guid_list = missing_guids.map { |g| "'#{g}'" }.join(', ')
      unprocessable!("Unable to share to spaces [#{guid_list}] for the service instance. Ensure the spaces exist and you have access to them.")
    end
  end

  def can_read_service_instance?(service_instance)
    readable_spaces = service_instance.shared_spaces + [service_instance.space]

    readable_spaces.any? do |space|
      can_read?(space.guid, space.organization_guid)
    end
  end

  def can_read_space?(space)
    can_read?(space.guid, space.organization.guid)
  end

  def can_write_space?(space)
    can_write?(space.guid)
  end
end
