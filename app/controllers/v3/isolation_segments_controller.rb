require 'actions/isolation_segment_assign'
require 'actions/isolation_segment_unassign'
require 'actions/isolation_segment_update'
require 'actions/isolation_segment_delete'
require 'actions/isolation_segment_create'

require 'messages/isolation_segment_relationship_org_message'
require 'messages/isolation_segment_create_message'
require 'messages/isolation_segment_update_message'
require 'messages/isolation_segments_list_message'

require 'presenters/v3/isolation_segment_presenter'
require 'presenters/v3/relationship_presenter'
require 'presenters/v3/to_many_relationship_presenter'

require 'fetchers/isolation_segment_list_fetcher'
require 'fetchers/isolation_segment_organizations_fetcher'
require 'fetchers/isolation_segment_spaces_fetcher'

class IsolationSegmentsController < ApplicationController
  def create
    unauthorized! unless roles.admin?

    message = IsolationSegmentCreateMessage.new(hashed_params[:body])
    unprocessable!(message.errors.full_messages) unless message.valid?

    isolation_segment = IsolationSegmentCreate.create(message)

    render status: :created, json: Presenters::V3::IsolationSegmentPresenter.new(isolation_segment)
  rescue IsolationSegmentCreate::Error => e
    unprocessable!(e.message)
  end

  def show
    isolation_segment_model = find_readable_isolation_segment(hashed_params[:guid])

    render status: :ok, json: Presenters::V3::IsolationSegmentPresenter.new(isolation_segment_model)
  end

  def index
    message = IsolationSegmentsListMessage.from_params(query_params)
    invalid_param!(message.errors.full_messages) unless message.valid?

    dataset = if permission_queryer.can_read_globally?
                IsolationSegmentListFetcher.fetch_all(message)
              else
                IsolationSegmentListFetcher.fetch_for_organizations(message, org_guids_query: permission_queryer.readable_org_guids_query)
              end

    render status: :ok, json: Presenters::V3::PaginatedListPresenter.new(
      presenter: Presenters::V3::IsolationSegmentPresenter,
      paginated_result: SequelPaginator.new.get_page(dataset, message.try(:pagination_options)),
      path: '/v3/isolation_segments',
      message: message
    )
  end

  def destroy
    unauthorized! unless roles.admin?

    isolation_segment_model = find_isolation_segment(hashed_params[:guid])
    IsolationSegmentDelete.new.delete(isolation_segment_model)

    head :no_content
  rescue IsolationSegmentDelete::AssociationNotEmptyError => e
    unprocessable!(e.message)
  end

  def update
    unauthorized! unless roles.admin?

    isolation_segment_model = find_isolation_segment(hashed_params[:guid])

    message = IsolationSegmentUpdateMessage.new(hashed_params[:body])
    unprocessable!(message.errors.full_messages) unless message.valid?

    IsolationSegmentUpdate.new.update(isolation_segment_model, message)

    isolation_segment_model.reload

    render status: :ok, json: Presenters::V3::IsolationSegmentPresenter.new(isolation_segment_model)
  rescue IsolationSegmentUpdate::InvalidIsolationSegment => e
    unprocessable!(e.message)
  end

  def relationships_orgs
    isolation_segment_model = find_readable_isolation_segment(hashed_params[:guid])

    fetcher = IsolationSegmentOrganizationsFetcher.new(isolation_segment_model)
    organizations = if permission_queryer.can_read_globally?
                      fetcher.fetch_all
                    else
                      fetcher.fetch_for_organizations(org_guids_query: permission_queryer.readable_org_guids_query)
                    end

    render status: :ok, json: Presenters::V3::ToManyRelationshipPresenter.new(
      "isolation_segments/#{isolation_segment_model.guid}", organizations, 'organizations')
  end

  def relationships_spaces
    isolation_segment_model = find_readable_isolation_segment(hashed_params[:guid])

    fetcher = IsolationSegmentSpacesFetcher.new(isolation_segment_model)
    spaces = if permission_queryer.can_read_globally?
               fetcher.fetch_all
             else
               fetcher.fetch_for_spaces(space_guids: permission_queryer.readable_space_guids_query)
             end

    render status: :ok, json: Presenters::V3::ToManyRelationshipPresenter.new(
      "isolation_segments/#{isolation_segment_model.guid}", spaces, 'spaces',
      build_related: false)
  end

  def assign_allowed_organizations
    unauthorized! unless roles.admin?
    isolation_segment_model, orgs = organizations_lookup

    organization_assigner.assign(isolation_segment_model, orgs)

    render status: :ok, json: Presenters::V3::ToManyRelationshipPresenter.new(
      "isolation_segments/#{isolation_segment_model.guid}", isolation_segment_model.organizations, 'organizations')
  end

  def unassign_allowed_organization
    unauthorized! unless roles.admin?

    isolation_segment_model = IsolationSegmentModel.first(guid: hashed_params[:guid])
    resource_not_found!(:isolation_segment) unless isolation_segment_model

    org = Organization.first(guid: hashed_params[:org_guid])
    resource_not_found!(:org) unless org

    organization_unassigner.unassign(isolation_segment_model, org)

    head :no_content
  end

  private

  def organization_assigner
    @organization_assigner ||= IsolationSegmentAssign.new
  end

  def organization_unassigner
    @organization_unassigner ||= IsolationSegmentUnassign.new
  end

  def organizations_lookup
    isolation_segment_model = IsolationSegmentModel.first(guid: hashed_params[:guid])
    resource_not_found!(:isolation_segment) unless isolation_segment_model

    message = IsolationSegmentRelationshipOrgMessage.new(hashed_params[:body])
    unprocessable!(message.errors.full_messages) unless message.valid?

    organizations = Organization.where(guid: message.guids).all
    missing_guids = message.guids - organizations.map(&:guid)
    unless missing_guids.empty?
      guid_list = missing_guids.map { |g| "'#{g}'" }.join(', ')
      unprocessable!("Unable to entitle organizations [#{guid_list}] for the isolation segment. Ensure the organizations exist.")
    end

    [isolation_segment_model, organizations]
  end

  def find_isolation_segment(guid)
    isolation_segment = IsolationSegmentModel.first(guid: guid)
    resource_not_found!(:isolation_segment) unless isolation_segment
    isolation_segment
  end

  def find_readable_isolation_segment(guid)
    isolation_segment = if permission_queryer.can_read_globally?
                          IsolationSegmentModel.first(guid: guid)
                        else
                          IsolationSegmentModel.dataset.where(organizations: permission_queryer.readable_org_guids_query).first(guid: guid)
                        end
    resource_not_found!(:isolation_segment) unless isolation_segment
    isolation_segment
  end
end
