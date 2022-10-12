require 'actions/organization_quota_apply'
require 'actions/organization_quota_delete'
require 'actions/organization_quotas_create'
require 'actions/organization_quotas_update'
require 'messages/organization_quota_apply_message'
require 'messages/organization_quotas_create_message'
require 'messages/organization_quotas_list_message'
require 'fetchers/organization_quota_list_fetcher'
require 'presenters/v3/organization_quota_presenter'
require 'presenters/v3/to_many_relationship_presenter'

class OrganizationQuotasController < ApplicationController
  def create
    unauthorized! unless permission_queryer.can_write_globally?

    message = VCAP::CloudController::OrganizationQuotasCreateMessage.new(hashed_params[:body])
    unprocessable!(message.errors.full_messages) unless message.valid?

    organization_quota = OrganizationQuotasCreate.new.create(message)

    render json: Presenters::V3::OrganizationQuotaPresenter.new(organization_quota, **presenter_args), status: :created
  rescue OrganizationQuotasCreate::Error => e
    unprocessable!(e.message)
  end

  def update
    unauthorized! unless permission_queryer.can_write_globally?

    message = VCAP::CloudController::OrganizationQuotasUpdateMessage.new(hashed_params[:body])
    unprocessable!(message.errors.full_messages) unless message.valid?

    organization_quota = QuotaDefinition.first(guid: hashed_params[:guid])
    resource_not_found!(:organization_quota) unless organization_quota

    organization_quota = OrganizationQuotasUpdate.update(organization_quota, message)

    render json: Presenters::V3::OrganizationQuotaPresenter.new(organization_quota, **presenter_args), status: :ok
  rescue OrganizationQuotasUpdate::Error => e
    unprocessable!(e.message)
  end

  def show
    organization_quota = QuotaDefinition.first(guid: hashed_params[:guid])
    resource_not_found!(:organization_quota) unless organization_quota

    render json: Presenters::V3::OrganizationQuotaPresenter.new(organization_quota, **presenter_args), status: :ok
  rescue OrganizationQuotasCreate::Error => e
    unprocessable!(e.message)
  end

  def index
    message = OrganizationQuotasListMessage.from_params(query_params)
    invalid_param!(message.errors.full_messages) unless message.valid?

    if permission_queryer.can_read_globally?
      dataset = OrganizationQuotaListFetcher.fetch_all(message: message)
    else
      dataset = OrganizationQuotaListFetcher.fetch(message: message, readable_org_guids_query: permission_queryer.readable_org_guids_query)
    end

    render status: :ok, json: Presenters::V3::PaginatedListPresenter.new(
      presenter: Presenters::V3::OrganizationQuotaPresenter,
      paginated_result: SequelPaginator.new.get_page(dataset, message.try(:pagination_options)),
      path: '/v3/organization_quotas',
      message: message,
      extra_presenter_args: presenter_args,
    )
  end

  def destroy
    unauthorized! unless permission_queryer.can_write_globally?

    organization_quota = QuotaDefinition.first(guid: hashed_params[:guid])
    resource_not_found!(:organization_quota) unless organization_quota

    if Organization.find(quota_definition_id: organization_quota.id)
      unprocessable!('This quota is applied to one or more organizations. Apply different quotas to those organizations before deleting.')
    end

    delete_action = OrganizationQuotaDeleteAction.new

    deletion_job = VCAP::CloudController::Jobs::DeleteActionJob.new(QuotaDefinition, organization_quota.guid, delete_action, 'organization_quota')
    pollable_job = Jobs::Enqueuer.new(deletion_job, queue: Jobs::Queues.generic).enqueue_pollable

    head :accepted, 'Location' => url_builder.build_url(path: "/v3/jobs/#{pollable_job.guid}")
  end

  def apply_to_organizations
    unauthorized! unless permission_queryer.can_write_globally?

    message = OrganizationQuotaApplyMessage.new(hashed_params[:body])
    unprocessable!(message.errors.full_messages) unless message.valid?

    organization_quota = QuotaDefinition.first(guid: hashed_params[:guid])
    resource_not_found!(:organization_quota) unless organization_quota

    OrganizationQuotaApply.new.apply(organization_quota, message)

    render status: :ok, json: Presenters::V3::ToManyRelationshipPresenter.new(
      "organization_quotas/#{organization_quota.guid}",
      organization_quota.organizations,
      'organizations',
      build_related: false
    )
  rescue OrganizationQuotaApply::Error => e
    unprocessable!(e.message)
  end

  def presenter_args
    if permission_queryer.can_read_globally?
      { all_orgs_visible: true }
    else
      { visible_org_guids_query: permission_queryer.readable_org_guids_query }
    end
  end
end
