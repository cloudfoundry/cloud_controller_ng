require 'queries/app_droplets_list_fetcher'
require 'messages/apps_droplets_list_message'

class AppsDropletsController < ApplicationController
  def index
    app_guid = params[:guid]
    message = AppsDropletsListMessage.from_params(query_params)
    invalid_param!(message.errors.full_messages) unless message.valid?

    pagination_options = PaginationOptions.from_params(query_params)
    invalid_param!(pagination_options.errors.full_messages) unless pagination_options.valid?

    app, space, org = AppFetcher.new.fetch(app_guid)
    app_not_found! if app.nil? || !can_read?(space.guid, org.guid)

    paginated_result = AppDropletsListFetcher.new.fetch(app_guid, pagination_options, message)

    render :ok, json: DropletPresenter.new.present_json_list(paginated_result, "/v3/apps/#{params[:guid]}/droplets", message)
  end

  private

  def membership
    @membership ||= Membership.new(current_user)
  end

  def can_read?(space_guid, org_guid)
    roles.admin? ||
      membership.has_any_roles?([Membership::SPACE_DEVELOPER,
                                 Membership::SPACE_MANAGER,
                                 Membership::SPACE_AUDITOR,
                                 Membership::ORG_MANAGER], space_guid, org_guid)
  end

  def app_not_found!
    raise VCAP::Errors::ApiError.new_from_details('ResourceNotFound', 'App not found')
  end
end
