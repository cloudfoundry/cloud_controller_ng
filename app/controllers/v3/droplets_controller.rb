require 'presenters/v3/droplet_presenter'
require 'queries/droplet_delete_fetcher'
require 'actions/droplet_delete'
require 'queries/droplet_list_fetcher'
require 'messages/droplets_list_message'
require 'cloud_controller/membership'

class DropletsController < ApplicationController
  ROLES_FOR_READING =  [
    Membership::SPACE_DEVELOPER,
    Membership::SPACE_MANAGER,
    Membership::SPACE_AUDITOR,
    Membership::ORG_MANAGER
  ].freeze

  def index
    message = DropletsListMessage.from_params(query_params)
    invalid_param!(message.errors.full_messages) unless message.valid?

    pagination_options = PaginationOptions.from_params(query_params)
    invalid_param!(pagination_options.errors.full_messages) unless pagination_options.valid?

    if roles.admin?
      paginated_result = DropletListFetcher.new.fetch_all(pagination_options, message)
    else
      space_guids = membership.space_guids_for_roles(ROLES_FOR_READING)
      paginated_result = DropletListFetcher.new.fetch(pagination_options, space_guids, message)
    end

    render status: :ok, json: droplet_presenter.present_json_list(paginated_result, '/v3/droplets', message)
  end

  def show
    droplet = DropletModel.where(guid: params[:guid]).eager(:space, space: :organization).all.first
    droplet_not_found! if droplet.nil? || !can_read?(droplet.space.guid, droplet.space.organization.guid)
    render status: :ok, json: droplet_presenter.present_json(droplet)
  end

  def destroy
    droplet, space, org = DropletDeleteFetcher.new.fetch(params[:guid])
    droplet_not_found! if droplet.nil? || !can_read?(space.guid, org.guid)

    unauthorized! unless can_delete?(space.guid)

    DropletDelete.new.delete(droplet)

    head :no_content
  end

  private

  def can_read?(space_guid, org_guid)
    roles.admin? || membership.has_any_roles?(ROLES_FOR_READING, space_guid, org_guid)
  end

  def can_delete?(space_guid)
    roles.admin? || membership.has_any_roles?([Membership::SPACE_DEVELOPER], space_guid)
  end

  def droplet_not_found!
    raise VCAP::Errors::ApiError.new_from_details('ResourceNotFound', 'Droplet not found')
  end

  def droplet_presenter
    @droplet_presenter ||= DropletPresenter.new
  end

  def membership
    @membership ||= Membership.new(current_user)
  end
end
