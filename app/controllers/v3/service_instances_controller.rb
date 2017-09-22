require 'messages/to_many_relationship_message'

require 'presenters/v3/relationship_presenter'
require 'presenters/v3/to_many_relationship_presenter'

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

    service_instance.db.transaction do
      spaces.each do |space|
        service_instance.add_shared_space(space)
      end
    end

    render status: :ok, json: Presenters::V3::ToManyRelationshipPresenter.new(
      "service_instances/#{service_instance.guid}", service_instance.shared_spaces, 'shared_spaces')
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

  def can_read_space?(space)
    can_read?(space.guid, space.organization_guid)
  end

  def can_write_space?(space)
    can_write?(space.guid)
  end
end
