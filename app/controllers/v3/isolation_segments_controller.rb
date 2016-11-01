require 'actions/isolation_segment_assign'
require 'actions/isolation_segment_unassign'
require 'actions/isolation_segment_update'

require 'messages/isolation_segment_relationship_org_message'
require 'messages/isolation_segment_create_message'
require 'messages/isolation_segment_update_message'
require 'messages/isolation_segments_list_message'

require 'presenters/v3/isolation_segment_presenter'
require 'presenters/v3/relationship_presenter'

require 'queries/isolation_segment_list_fetcher'
require 'queries/isolation_segment_organizations_fetcher'
require 'queries/isolation_segment_spaces_fetcher'

class IsolationSegmentsController < ApplicationController
  def create
    unauthorized! unless roles.admin?

    message = IsolationSegmentCreateMessage.create_from_http_request(params[:body])
    unprocessable!(message.errors.full_messages) unless message.valid?

    isolation_segment = nil
    IsolationSegmentModel.db.transaction do
      isolation_segment = IsolationSegmentModel.create(
        name: message.name,
      )
    end

    render status: :created, json: Presenters::V3::IsolationSegmentPresenter.new(isolation_segment)
  rescue Sequel::ValidationFailed => e
    unprocessable!(e.message)
  end

  def show
    isolation_segment_model = find_isolation_segment(params[:guid])
    resource_not_found!(:isolation_segment) unless can_read_isolation_segment?(isolation_segment_model)

    render status: :ok, json: Presenters::V3::IsolationSegmentPresenter.new(isolation_segment_model)
  end

  def index
    message = IsolationSegmentsListMessage.from_params(query_params)
    invalid_param!(message.errors.full_messages) unless message.valid?
    invalid_param!(message.pagination_options.errors.full_messages) unless message.pagination_options.valid?

    fetcher = IsolationSegmentListFetcher.new(message: message)

    dataset = if roles.admin? || roles.admin_read_only?
                fetcher.fetch_all
              else
                fetcher.fetch_for_organizations(org_guids: readable_org_guids)
              end

    render status: :ok, json: Presenters::V3::PaginatedListPresenter.new(dataset: dataset, path: '/v3/isolation_segments', message: message)
  end

  def destroy
    unauthorized! unless roles.admin?

    isolation_segment_model = find_isolation_segment(params[:guid])

    unprocessable!("Cannot delete the #{isolation_segment_model.name} Isolation Segment") if
      isolation_segment_model.guid.eql?(VCAP::CloudController::IsolationSegmentModel::SHARED_ISOLATION_SEGMENT_GUID)

    isolation_segment_model.db.transaction do
      isolation_segment_model.lock!
      isolation_segment_model.destroy
    end

    head :no_content
  end

  def update
    unauthorized! unless roles.admin?

    isolation_segment_model = find_isolation_segment(params[:guid])
    unprocessable!("Cannot update the #{isolation_segment_model.name} Isolation Segment") if
      isolation_segment_model.guid.eql?(VCAP::CloudController::IsolationSegmentModel::SHARED_ISOLATION_SEGMENT_GUID)

    message = IsolationSegmentUpdateMessage.create_from_http_request(params[:body])
    unprocessable!(message.errors.full_messages) unless message.valid?

    IsolationSegmentUpdate.new.update(isolation_segment_model, message)

    isolation_segment_model.reload

    render status: :ok, json: Presenters::V3::IsolationSegmentPresenter.new(isolation_segment_model)
  rescue IsolationSegmentUpdate::InvalidIsolationSegment => e
    unprocessable!(e.message)
  end

  def relationships_orgs
    isolation_segment_model = find_isolation_segment(params[:guid])
    resource_not_found!(:isolation_segment) unless can_list_organizations?(isolation_segment_model)

    fetcher = IsolationSegmentOrganizationsFetcher.new(isolation_segment_model)
    organizations = if roles.admin? || roles.admin_read_only?
                      fetcher.fetch_all
                    else
                      fetcher.fetch_for_organizations(org_guids: readable_org_guids)
                    end

    render status: :ok, json: Presenters::V3::RelationshipPresenter.new('organizations', organizations)
  end

  def relationships_spaces
    isolation_segment_model = find_isolation_segment(params[:guid])
    resource_not_found!(:isolation_segment) unless can_read_isolation_segment?(isolation_segment_model)

    fetcher = IsolationSegmentSpacesFetcher.new(isolation_segment_model)
    spaces = if roles.admin? || roles.admin_read_only?
               fetcher.fetch_all
             else
               fetcher.fetch_for_spaces(space_guids: readable_space_guids)
             end

    render status: :ok, json: Presenters::V3::RelationshipPresenter.new('spaces', spaces)
  end

  def assign_allowed_organizations
    unauthorized! unless roles.admin?
    isolation_segment_model, orgs = organizations_lookup

    organization_assigner.assign(isolation_segment_model, orgs)

    render status: :created, json: Presenters::V3::IsolationSegmentPresenter.new(isolation_segment_model)
  end

  def unassign_allowed_organizations
    unauthorized! unless roles.admin?
    isolation_segment_model, orgs = organizations_lookup

    organization_unassigner.unassign(isolation_segment_model, orgs)

    head :no_content
  rescue IsolationSegmentUnassign::IsolationSegmentUnassignError => e
    unprocessable!(e.message)
  end

  private

  def organization_assigner
    @organization_assigner ||= IsolationSegmentAssign.new
  end

  def organization_unassigner
    @organization_unassigner ||= IsolationSegmentUnassign.new
  end

  def organizations_lookup
    isolation_segment_model = IsolationSegmentModel.first(guid: params[:guid])
    resource_not_found!(:isolation_segment) unless isolation_segment_model

    message = IsolationSegmentRelationshipOrgMessage.create_from_http_request(params[:body])
    unprocessable!(message.errors.full_messages) unless message.valid?

    organizations = Organization.where(guid: message.guids).all
    resources_not_found!("Organization guids: #{message.guids - organizations.map(&:guid)} cannot be found") unless organizations.length == message.guids.length

    [isolation_segment_model, organizations]
  end

  def can_read_isolation_segment?(isolation_segment)
    roles.admin? ||
      isolation_segment.spaces.any? { |space| can_read?(space.guid, space.organization.guid) } ||
      isolation_segment.organizations.any? { |org| can_read_from_org?(org.guid) }
  end

  def can_list_organizations?(isolation_segment)
    roles.admin? || isolation_segment.organizations.any? { |org| can_read_from_org?(org.guid) }
  end

  def find_isolation_segment(guid)
    isolation_segment = IsolationSegmentModel.first(guid: guid)
    resource_not_found!(:isolation_segment) unless isolation_segment
    isolation_segment
  end
end
