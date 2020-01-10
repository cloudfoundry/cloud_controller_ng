require 'actions/organization_quotas_create'
require 'messages/organization_quotas_create_message'
require 'messages/organization_quotas_list_message'
require 'fetchers/organization_quota_list_fetcher'
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

    visible_organizations_guids = permission_queryer.readable_org_guids

    render json: Presenters::V3::OrganizationQuotasPresenter.new(organization_quota, visible_org_guids: visible_organizations_guids), status: :ok
  rescue OrganizationQuotasCreate::Error => e
    unprocessable!(e.message)
  end

  def index
    message = OrganizationQuotasListMessage.from_params(query_params)
    invalid_param!(message.errors.full_messages) unless message.valid?

    dataset = OrganizationQuotaListFetcher.fetch(message: message, readable_org_guids: permission_queryer.readable_org_guids)

    render status: :ok, json: Presenters::V3::PaginatedListPresenter.new(
      presenter: Presenters::V3::OrganizationQuotasPresenter,
      paginated_result: SequelPaginator.new.get_page(dataset, message.try(:pagination_options)),
      path: '/v3/organization_quotas',
      message: message,
      extra_presenter_args: { visible_org_guids: permission_queryer.readable_org_guids },
    )
  end
end
