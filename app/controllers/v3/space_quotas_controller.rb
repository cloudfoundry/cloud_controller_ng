require 'actions/space_quotas_create'
require 'actions/space_quota_update'
require 'actions/space_quota_apply'
require 'actions/space_quota_unapply'
require 'actions/space_quota_delete'
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

    org = Organization.find(guid: message.organization_guid)
    unprocessable_organization!(message.organization_guid) unless org

    unauthorized! unless permission_queryer.can_write_to_active_org?(org.id)
    suspended! unless permission_queryer.is_org_active?(org.id)

    space_quota = SpaceQuotasCreate.new.create(message, organization: org)

    render status: :created, json: Presenters::V3::SpaceQuotaPresenter.new(
      space_quota,
      **presenter_args
    )
  rescue SpaceQuotasCreate::Error => e
    unprocessable!(e.message)
  end

  def show
    space_quota = SpaceQuotaDefinition.first(guid: hashed_params[:guid])
    resource_not_found!(:space_quota) unless space_quota && readable_space_quota_guids.include?(space_quota.guid)

    render status: :ok, json: Presenters::V3::SpaceQuotaPresenter.new(
      space_quota,
      **presenter_args
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
      extra_presenter_args: presenter_args,
    )
  end

  def update
    space_quota = SpaceQuotaDefinition.first(guid: hashed_params[:guid])

    resource_not_found!(:space_quota) unless space_quota &&
      readable_space_quota_guids.include?(space_quota.guid)

    unauthorized! unless permission_queryer.can_write_globally? ||
      (space_quota && permission_queryer.can_write_to_active_org?(space_quota.organization_id))
    suspended! unless space_quota && permission_queryer.is_org_active?(space_quota.organization_id)

    message = VCAP::CloudController::OrganizationQuotasUpdateMessage.new(hashed_params[:body])
    unprocessable!(message.errors.full_messages) unless message.valid?

    space_quota = SpaceQuotaUpdate.update(space_quota, message)

    render status: :ok, json: Presenters::V3::SpaceQuotaPresenter.new(
      space_quota,
      **presenter_args
    )
  rescue SpaceQuotaUpdate::Error => e
    unprocessable!(e.message)
  end

  def apply_to_spaces
    space_quota = SpaceQuotaDefinition.first(guid: hashed_params[:guid])

    resource_not_found!(:space_quota) unless space_quota &&
      readable_space_quota_guids.include?(space_quota.guid)

    unauthorized! unless permission_queryer.can_write_globally? ||
      (space_quota && permission_queryer.can_write_to_active_org?(space_quota.organization_id))
    suspended! unless space_quota && permission_queryer.is_org_active?(space_quota.organization_id)

    message = SpaceQuotaApplyMessage.new(hashed_params[:body])
    unprocessable!(message.errors.full_messages) unless message.valid?

    SpaceQuotaApply.new.apply(space_quota, message, **presenter_args)

    render status: :ok, json: Presenters::V3::ToManyRelationshipPresenter.new(
      "space_quotas/#{space_quota.guid}",
      space_quota.spaces,
      'spaces',
      build_related: false
    )
  rescue SpaceQuotaApply::Error => e
    unprocessable!(e.message)
  end

  def remove_from_space
    space_quota = SpaceQuotaDefinition.first(guid: hashed_params[:guid])

    resource_not_found!(:space_quota) unless space_quota &&
      readable_space_quota_guids.include?(space_quota.guid)

    unauthorized! unless permission_queryer.can_write_globally? ||
      (space_quota && permission_queryer.can_write_to_active_org?(space_quota.organization_id))
    suspended! unless space_quota && permission_queryer.is_org_active?(space_quota.organization_id)

    space_guid = hashed_params[:space_guid]
    space = Space.first(guid: space_guid)

    unless space && space.space_quota_definition_guid == space_quota.guid
      unprocessable!("Unable to remove quota from space with guid '#{space_guid}'. Ensure the space quota is applied to this space.")
    end

    SpaceQuotaUnapply.unapply(space_quota, space)
  rescue SpaceQuotaUnapply::Error => e
    unprocessable!(e.message)
  end

  def destroy
    space_quota = SpaceQuotaDefinition.first(guid: hashed_params[:guid])

    resource_not_found!(:space_quota) unless space_quota &&
      readable_space_quota_guids.include?(space_quota.guid)

    unauthorized! unless permission_queryer.can_write_globally? ||
      (space_quota && permission_queryer.can_write_to_active_org?(space_quota.organization_id))
    suspended! unless space_quota && permission_queryer.is_org_active?(space_quota.organization_id)

    unprocessable!('This quota is applied to one or more spaces. Remove this quota from all spaces before deleting.') unless space_quota.spaces_dataset.empty?

    delete_action = SpaceQuotaDeleteAction.new

    deletion_job = VCAP::CloudController::Jobs::DeleteActionJob.new(SpaceQuotaDefinition, space_quota.guid, delete_action, 'space_quota')
    pollable_job = Jobs::Enqueuer.new(deletion_job, queue: Jobs::Queues.generic).enqueue_pollable

    head :accepted, 'Location' => url_builder.build_url(path: "/v3/jobs/#{pollable_job.guid}")
  end

  private

  def unprocessable_organization!(org_guid)
    unprocessable!("Organization with guid '#{org_guid}' does not exist, or you do not have access to it.")
  end

  def readable_space_quota_guids
    permission_queryer.readable_space_quota_guids
  end

  def presenter_args
    if permission_queryer.can_read_globally?
      { all_spaces_visible: true }
    else
      { visible_space_guids: permission_queryer.readable_space_guids }
    end
  end
end
