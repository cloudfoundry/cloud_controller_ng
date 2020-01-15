require 'actions/space_quotas_create'
require 'messages/space_quotas_create_message'
require 'presenters/v3/space_quota_presenter'

class SpaceQuotasController < ApplicationController
  def create
    unauthorized! unless permission_queryer.can_write_globally?

    message = VCAP::CloudController::SpaceQuotasCreateMessage.new(hashed_params[:body])
    unprocessable!(message.errors.full_messages) unless message.valid?

    org = Organization.find(guid: message.organization_guid)
    error!("Organization with guid '#{message.organization_guid}' does not exist, or you do not have access to it.") unless org && permission_queryer.can_write_to_org?(org)

    space_quota = SpaceQuotasCreate.new.create(message, organization: org)
    render json: Presenters::V3::SpaceQuotaPresenter.new(space_quota), status: :created
  rescue SpaceQuotasCreate::Error => e
    unprocessable!(e.message)
  end
end
