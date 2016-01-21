require 'queries/app_droplets_list_fetcher'
require 'messages/apps_droplets_list_message'
require 'controllers/v3/mixins/app_subresource'

class AppsDropletsController < ApplicationController
  include AppSubresource

  def index
    app_guid = params[:guid]
    message = AppsDropletsListMessage.from_params(query_params)
    invalid_param!(message.errors.full_messages) unless message.valid?

    pagination_options = PaginationOptions.from_params(query_params)
    invalid_param!(pagination_options.errors.full_messages) unless pagination_options.valid?

    app, space, org = AppFetcher.new.fetch(app_guid)
    app_not_found! unless app && can_read?(space.guid, org.guid)

    paginated_result = AppDropletsListFetcher.new.fetch(app_guid, pagination_options, message)

    render :ok, json: DropletPresenter.new.present_json_list(paginated_result, "/v3/apps/#{params[:guid]}/droplets", message)
  end

  private

  def app_not_found!
    resource_not_found!(:app)
  end
end
