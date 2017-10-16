require 'messages/to_many_relationship_message'
require 'repositories/service_instance_share_event_repository'

require 'presenters/v3/relationship_presenter'
require 'presenters/v3/to_many_relationship_presenter'
require 'actions/service_instance_share'
require 'actions/service_instance_unshare'

class ServiceInstancesV3Controller < ApplicationController
  def share_service_instance
    FeatureFlag.raise_unless_enabled!(:service_instance_sharing)

    service_instance = ServiceInstance.first(guid: params[:service_instance_guid])

    resource_not_found!(:service_instance) unless service_instance && can_read_space?(service_instance.space)
    unauthorized! unless can_write_space?(service_instance.space)

    message = VCAP::CloudController::ToManyRelationshipMessage.create_from_http_request(params[:body])
    unprocessable!(message.errors.full_messages) unless message.valid?

    spaces = Space.where(guid: message.guids)
    check_spaces_exist_and_are_readable!(message.guids, spaces)
    check_spaces_are_writeable!(spaces)

    share = ServiceInstanceShare.new
    share.create(service_instance, spaces, user_audit_info, message.guids)

    render status: :ok, json: Presenters::V3::ToManyRelationshipPresenter.new(
      "service_instances/#{service_instance.guid}", service_instance.shared_spaces, 'shared_spaces')
  end

  def unshare_service_instance
    FeatureFlag.raise_unless_enabled!(:service_instance_sharing)

    service_instance = ServiceInstance.first(guid: params[:service_instance_guid])

    resource_not_found!(:service_instance) unless service_instance && can_read_space?(service_instance.space)
    unauthorized! unless can_write_space?(service_instance.space)

    space_guid = params[:space_guid]
    target_space = Space.first(guid: space_guid)

    unless target_space && service_instance.shared_spaces.include?(target_space)
      unprocessable!("Unable to unshare service instance from space #{space_guid}. Ensure the space exists and the service instance has been shared to this space.")
    end

    if bound_apps_in_target_space?(service_instance, target_space)
      unprocessable!("Unable to unshare service instance from space #{space_guid}. Ensure no bindings exist in the target space")
    end

    unshare = ServiceInstanceUnshare.new
    unshare.unshare(service_instance, target_space, user_audit_info)

    head :no_content
  end

  private

  def bound_apps_in_target_space?(service_instance, target_space)
    active_bindings = ServiceBinding.where(service_instance_guid: service_instance.guid)
    bound_app_space_guids = active_bindings.map { |b| b.app.space_guid }

    bound_app_space_guids.include?(target_space.guid)
  end

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

  def can_read_space?(space)
    can_read?(space.guid, space.organization_guid)
  end

  def can_write_space?(space)
    can_write?(space.guid)
  end
end
