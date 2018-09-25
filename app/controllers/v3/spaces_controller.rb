require 'presenters/v3/paginated_list_presenter'
require 'presenters/v3/space_presenter'
require 'messages/space_create_message'
require 'messages/space_update_isolation_segment_message'
require 'messages/spaces_list_message'
require 'actions/space_update_isolation_segment'
require 'actions/space_create'
require 'fetchers/space_list_fetcher'
require 'fetchers/space_fetcher'

class SpacesV3Controller < ApplicationController
  def show
    space = SpaceFetcher.new.fetch(hashed_params[:guid])

    space_not_found! unless space && permission_queryer.can_read_from_space?(space.guid, space.organization.guid)

    render status: :ok, json: Presenters::V3::SpacePresenter.new(space)
  end

  def create
    message = SpaceCreateMessage.new(hashed_params[:body])
    missing_org = 'Invalid organization. Ensure the organization exists and you have access to it.'

    unprocessable!(missing_org) unless permission_queryer.can_read_from_org?(message.organization_guid)
    unauthorized! unless permission_queryer.can_write_to_org?(message.organization_guid)
    unprocessable!(message.errors.full_messages) unless message.valid?

    org = fetch_organization(message.organization_guid)
    unprocessable!(missing_org) unless org
    space = SpaceCreate.new(perm_client: perm_client).create(org, message)

    render status: 201, json: Presenters::V3::SpacePresenter.new(space)
  rescue SpaceCreate::Error => e
    unprocessable!(e.message)
  end

  def index
    message = SpacesListMessage.from_params(query_params)
    invalid_param!(message.errors.full_messages) unless message.valid?

    render status: :ok, json: Presenters::V3::PaginatedListPresenter.new(
      presenter: Presenters::V3::SpacePresenter,
      paginated_result: SequelPaginator.new.get_page(readable_spaces(message: message), message.try(:pagination_options)),
      path: '/v3/spaces',
      message: message
    )
  end

  def update_isolation_segment
    space = fetch_space(hashed_params[:guid])
    space_not_found! unless space
    org = space.organization
    org_not_found! unless org
    space_not_found! unless permission_queryer.can_read_from_space?(space.guid, org.guid)
    unauthorized! unless roles.admin? || space.organization.managers.include?(current_user)

    message = SpaceUpdateIsolationSegmentMessage.new(hashed_params[:body])
    unprocessable!(message.errors.full_messages) unless message.valid?

    SpaceUpdateIsolationSegment.new(user_audit_info).update(space, org, message)

    isolation_segment = fetch_isolation_segment(message.isolation_segment_guid)
    render status: :ok, json: Presenters::V3::ToOneRelationshipPresenter.new(
      resource_path: "spaces/#{space.guid}",
      related_instance: isolation_segment,
      relationship_name: 'isolation_segment',
      related_resource_name: 'isolation_segments'
    )
  rescue SpaceUpdateIsolationSegment::Error => e
    unprocessable!(e.message)
  end

  def show_isolation_segment
    space = fetch_space(hashed_params[:guid])
    space_not_found! unless space

    org = space.organization
    space_not_found! unless permission_queryer.can_read_from_space?(space.guid, org.guid)

    isolation_segment = fetch_isolation_segment(space.isolation_segment_guid)
    render status: :ok, json: Presenters::V3::ToOneRelationshipPresenter.new(
      resource_path: "spaces/#{space.guid}",
      related_instance: isolation_segment,
      relationship_name: 'isolation_segment',
      related_resource_name: 'isolation_segments'
    )
  end

  private

  def fetch_organization(guid)
    Organization.where(guid: guid).first
  end

  def fetch_space(guid)
    Space.where(guid: guid).first
  end

  def fetch_isolation_segment(guid)
    IsolationSegmentModel.where(guid: guid).first
  end

  def space_not_found!
    resource_not_found!(:space)
  end

  def org_not_found!
    resource_not_found!(:org)
  end

  def readable_spaces(message:)
    if permission_queryer.can_read_globally?
      if message.requested?(:guids)
        SpaceListFetcher.new.fetch(message: message, guids: message.guids)
      else
        SpaceListFetcher.new.fetch_all(message: message)
      end
    else
      readable_space_guids = permission_queryer.readable_space_guids
      filtered_readable_guids = message.requested?(:guids) ? readable_space_guids & message.guids : readable_space_guids
      SpaceListFetcher.new.fetch(message: message, guids: filtered_readable_guids)
    end
  end
end
