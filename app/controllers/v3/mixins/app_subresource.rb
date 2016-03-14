require 'cloud_controller/membership'
require 'queries/app_fetcher'

module AppSubresource
  ROLES_FOR_READING = [
    VCAP::CloudController::Membership::SPACE_DEVELOPER,
    VCAP::CloudController::Membership::SPACE_MANAGER,
    VCAP::CloudController::Membership::SPACE_AUDITOR,
    VCAP::CloudController::Membership::ORG_MANAGER
  ].freeze

  private

  def app_not_found!
    resource_not_found!(:app)
  end

  def can_read?(space_guid, org_guid)
    roles.admin? ||
      membership.has_any_roles?(ROLES_FOR_READING, space_guid, org_guid)
  end

  def readable_space_guids
    membership.space_guids_for_roles(ROLES_FOR_READING)
  end

  def base_url(resource:)
    if app_nested?
      "/v3/apps/#{params[:app_guid]}/#{resource}"
    else
      "/v3/#{resource}"
    end
  end

  def app_nested?
    params[:app_guid].present?
  end

  def app_subresource_query_params
    if app_nested?
      query_params.merge(app_guid: params[:app_guid])
    else
      query_params
    end
  end
end
