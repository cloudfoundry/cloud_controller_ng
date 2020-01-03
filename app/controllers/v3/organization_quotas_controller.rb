require 'actions/organization_quotas_create'
require 'messages/organization_quotas_create_message'
require 'presenters/v3/organization_quotas_presenter'

class OrganizationQuotasController < ApplicationController
  def create
    unauthorized! unless permission_queryer.can_write_globally?

    message = VCAP::CloudController::OrganizationQuotasCreateMessage.new(hashed_params[:body])
    unprocessable!(message.errors.full_messages) unless message.valid?

    organization_quota = OrganizationQuotasCreate.new.create(message)

    render json: Presenters::V3::OrganizationQuotasPresenter.new(organization_quota), status: :created
  rescue OrganizationQuotasCreate::Error => e
    unprocessable!(e.message)
  end

  def show
    organization_quota = QuotaDefinition.first(guid: hashed_params[:guid])
    resource_not_found!(:organization_quota) unless organization_quota

    if permission_queryer.can_read_globally?
      visible_orgs = organization_quota.organizations
    else
      visible_org_ids = Organization.user_visibility_filter(current_user)[:id]
      visible_orgs = Organization.where(quota_definition_id: organization_quota.id, id: visible_org_ids).all
    end

    render json: Presenters::V3::OrganizationQuotasPresenter.new(organization_quota, visible_organizations: visible_orgs), status: :ok
  rescue OrganizationQuotasCreate::Error => e
    unprocessable!(e.message)
  end
end
