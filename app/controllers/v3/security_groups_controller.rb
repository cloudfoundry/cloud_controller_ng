require 'messages/security_group_create_message'
require 'messages/security_group_list_message'
require 'actions/security_group_create'
require 'presenters/v3/security_group_presenter'

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
    dataset = SecurityGroup.where(guid: permission_queryer.readable_security_group_guids)

    render status: :ok, json: Presenters::V3::PaginatedListPresenter.new(
      presenter: Presenters::V3::SecurityGroupPresenter,
      paginated_result: SequelPaginator.new.get_page(dataset, message.try(:pagination_options)),
      path: '/v3/security_groups',
      message: message,
      extra_presenter_args: { visible_space_guids: permission_queryer.readable_space_guids },
    )
  end
end
