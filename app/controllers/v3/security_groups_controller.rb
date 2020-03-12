require 'messages/security_group_create_message'
require 'messages/security_group_list_message'
require 'messages/security_group_apply_message'
require 'messages/security_group_update_message'
require 'actions/security_group_create'
require 'actions/security_group_apply'
require 'actions/security_group_update'
require 'presenters/v3/security_group_presenter'
require 'fetchers/security_group_list_fetcher'

class SecurityGroupsController < ApplicationController
  def create
    unauthorized! unless permission_queryer.can_write_globally?

    message = SecurityGroupCreateMessage.new(hashed_params[:body])
    unprocessable!(message.errors.full_messages) unless message.valid?

    security_group = SecurityGroupCreate.create(message)

    render status: :created, json: Presenters::V3::SecurityGroupPresenter.new(
      security_group,
      visible_space_guids: permission_queryer.readable_space_guids
    )
  rescue SecurityGroupCreate::Error => e
    unprocessable!(e)
  end

  def create_running_spaces
    resource_not_found!(:security_group) unless permission_queryer.readable_security_group_guids.include?(hashed_params[:guid])
    security_group = SecurityGroup.first(guid: hashed_params[:guid])

    message = SecurityGroupApplyMessage.new(hashed_params[:body])
    unprocessable!(message.errors.full_messages) unless message.valid?

    unwritable_space_guids = message.space_guids.select do |space_guid|
      org = Space.find(guid: space_guid)&.organization
      org && !permission_queryer.can_update_space?(space_guid, org.guid)
    end
    unauthorized! if unwritable_space_guids.any?

    applied_spaces = SecurityGroupApply.apply_running(security_group, message, permission_queryer.readable_space_guids)

    render status: :ok, json: Presenters::V3::ToManyRelationshipPresenter.new(
      "security_groups/#{security_group.guid}",
      applied_spaces,
      'running_spaces',
      build_related: false
    )
  rescue SecurityGroupApply::Error => e
    unprocessable!(e)
  end

  def create_staging_spaces
    resource_not_found!(:security_group) unless permission_queryer.readable_security_group_guids.include?(hashed_params[:guid])
    security_group = SecurityGroup.first(guid: hashed_params[:guid])

    message = SecurityGroupApplyMessage.new(hashed_params[:body])
    unprocessable!(message.errors.full_messages) unless message.valid?

    unwritable_space_guids = message.space_guids.select do |space_guid|
      org = Space.find(guid: space_guid)&.organization
      org && !permission_queryer.can_update_space?(space_guid, org.guid)
    end
    unauthorized! if unwritable_space_guids.any?

    applied_spaces = SecurityGroupApply.apply_staging(security_group, message, permission_queryer.readable_space_guids)

    render status: :ok, json: Presenters::V3::ToManyRelationshipPresenter.new(
      "security_groups/#{security_group.guid}",
      applied_spaces,
      'staging_spaces',
      build_related: false
    )
  rescue SecurityGroupApply::Error => e
    unprocessable!(e)
  end

  def show
    resource_not_found!(:security_group) unless permission_queryer.readable_security_group_guids.include?(hashed_params[:guid])
    security_group = SecurityGroup.first(guid: hashed_params[:guid])

    render status: :ok, json: Presenters::V3::SecurityGroupPresenter.new(
      security_group,
      visible_space_guids: permission_queryer.readable_space_guids
    )
  end

  def index
    message = SecurityGroupListMessage.from_params(query_params)
    unprocessable!(message.errors.full_messages) unless message.valid?

    dataset = if permission_queryer.can_read_globally?
                SecurityGroupListFetcher.fetch_all(message)
              else
                SecurityGroupListFetcher.fetch(message, permission_queryer.readable_security_group_guids)
              end

    render status: :ok, json: Presenters::V3::PaginatedListPresenter.new(
      presenter: Presenters::V3::SecurityGroupPresenter,
      paginated_result: SequelPaginator.new.get_page(dataset, message.try(:pagination_options)),
      path: '/v3/security_groups',
      message: message,
      extra_presenter_args: { visible_space_guids: permission_queryer.readable_space_guids },
    )
  end

  def update
    resource_not_found!(:security_group) unless permission_queryer.readable_security_group_guids.include?(hashed_params[:guid])
    security_group = SecurityGroup.first(guid: hashed_params[:guid])

    unauthorized! unless permission_queryer.can_write_globally?

    message = SecurityGroupUpdateMessage.new(hashed_params[:body])
    unprocessable!(message.errors.full_messages) unless message.valid?

    updated_security_group = SecurityGroupUpdate.update(security_group, message)

    render status: :ok, json: Presenters::V3::SecurityGroupPresenter.new(
      updated_security_group,
      visible_space_guids: permission_queryer.readable_space_guids
    )
  rescue SecurityGroupUpdate::Error => e
    unprocessable!(e)
  end
end
