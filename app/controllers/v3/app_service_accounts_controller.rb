require 'actions/app_assign_service_account'
require 'messages/app_service_account_update_message'
require 'fetchers/app_fetcher'
require 'jobs/v3/service_account_provision'

class AppServiceAccountsController < ApplicationController
  def show
    app, = fetch_readable_app
    render status: :ok, json: relationship(app)
  end

  def update
    app, space = fetch_readable_app
    unauthorized! unless permission_queryer.can_write_to_active_space?(space.id)
    require_writable_space!(space)
    message = AppServiceAccountUpdateMessage.new(hashed_params[:body])
    unprocessable!(message.errors.full_messages) unless message.valid?

    account = ServiceAccountModel.where(guid: message.account_guid).first if message.account_guid
    resource_not_found!(:service_account) if message.account_guid && !account
    job = AppAssignServiceAccount.new(permission_queryer).assign(app, account, provision: Config.config.get(:service_account_provisioning_enabled) == true)
    add_warning_headers(["Restart #{app.name} for the service-account assignment change to take effect."])
    return head :accepted, 'Location' => url_builder.build_url(path: "/v3/jobs/#{job.guid}") if job.is_a?(PollableJobModel)

    render status: :ok, json: relationship(app)
  rescue AppAssignServiceAccount::Unauthorized
    unauthorized!
  rescue AppAssignServiceAccount::Conflict => e
    raise CloudController::Errors::V3::ApiError.new_from_details('ServiceAccountAssignmentConflict', e.message)
  end

  private

  def fetch_readable_app
    app, space = AppFetcher.new.fetch(hashed_params[:app_guid])
    resource_not_found!(:app) unless app && permission_queryer.can_read_from_space?(space.id, space.organization_id)
    [app, space]
  end

  def relationship(app)
    { data: app.service_account_guid ? { guid: app.service_account_guid } : nil }
  end
end
