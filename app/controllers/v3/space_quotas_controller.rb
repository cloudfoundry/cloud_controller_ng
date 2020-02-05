require 'actions/space_quotas_create'
require 'actions/space_quota_update'
require 'actions/space_quota_apply'
require 'fetchers/space_quota_list_fetcher'
require 'messages/space_quotas_create_message'
require 'messages/space_quotas_list_message'
require 'messages/space_quota_update_message'
require 'messages/space_quota_apply_message'
require 'presenters/v3/space_quota_presenter'

class SpaceQuotasController < ApplicationController
  def create
    message = VCAP::CloudController::SpaceQuotasCreateMessage.new(hashed_params[:body])
    unprocessable!(message.errors.full_messages) unless message.valid?

    unauthorized! unless permission_queryer.can_write_to_org?(message.organization_guid)

    org = Organization.find(guid: message.organization_guid)
    unprocessable_organization!(message.organization_guid) unless org

    space_quota = SpaceQuotasCreate.new.create(message, organization: org)

    render status: :created, json: Presenters::V3::SpaceQuotaPresenter.new(
      space_quota,
      visible_space_guids: permission_queryer.readable_space_guids
    )
  rescue SpaceQuotasCreate::Error => e
    unprocessable!(e.message)
  end

  def show
    space_quota = SpaceQuotaDefinition.first(guid: hashed_params[:guid])
    resource_not_found!(:space_quota) unless space_quota && readable_space_quota_guids.include?(space_quota.guid)

    render status: :ok, json: Presenters::V3::SpaceQuotaPresenter.new(
      space_quota,
      visible_space_guids: readable_space_guids
    )
  end

  def index
    message = VCAP::CloudController::SpaceQuotasListMessage.from_params(query_params)
    unprocessable!(message.errors.full_messages) unless message.valid?

    dataset = SpaceQuotaListFetcher.fetch(message: message, readable_space_quota_guids: readable_space_quota_guids)

    render status: :ok, json: Presenters::V3::PaginatedListPresenter.new(
      presenter: Presenters::V3::SpaceQuotaPresenter,
      paginated_result: SequelPaginator.new.get_page(dataset, message.try(:pagination_options)),
      path: '/v3/space_quotas',
      message: message,
      extra_presenter_args: { visible_space_guids: readable_space_guids },
    )
  end

  def update
    space_quota = SpaceQuotaDefinition.first(guid: hashed_params[:guid])
    unauthorized! unless permission_queryer.can_write_globally? ||
      (space_quota && permission_queryer.can_write_to_org?(space_quota.organization_guid))
    resource_not_found!(:space_quota) unless space_quota

    message = VCAP::CloudController::OrganizationQuotasUpdateMessage.new(hashed_params[:body])
    unprocessable!(message.errors.full_messages) unless message.valid?

    space_quota = SpaceQuotaUpdate.update(space_quota, message)

    render status: :ok, json: Presenters::V3::SpaceQuotaPresenter.new(
      space_quota,
      visible_space_guids: readable_space_guids
    )
  rescue SpaceQuotaUpdate::Error => e
    unprocessable!(e.message)
  end

  def apply_to_spaces
    space_quota = SpaceQuotaDefinition.first(guid: hashed_params[:guid])
    unauthorized! unless permission_queryer.can_write_globally? ||
      (space_quota && permission_queryer.can_write_to_org?(space_quota.organization_guid))
    resource_not_found!(:space_quota) unless space_quota

    message = SpaceQuotaApplyMessage.new(hashed_params[:body])
    invalid_param!(message.errors.full_messages) unless message.valid?

    SpaceQuotaApply.new.apply(space_quota, message)

    render status: :ok, json: Presenters::V3::ToManyRelationshipPresenter.new(
      "space_quotas/#{space_quota.guid}",
      space_quota.spaces,
      'spaces',
      build_related: false
    )
  rescue SpaceQuotaApply::Error => e
    unprocessable!(e.message)
  end

  private

  def unprocessable_organization!(org_guid)
    unprocessable!("Organization with guid '#{org_guid}' does not exist, or you do not have access to it.")
  end

  def readable_space_quota_guids
    permission_queryer.readable_space_quota_guids
  end

  def readable_space_guids
    permission_queryer.readable_space_guids
  end
end
