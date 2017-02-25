require 'actions/isolation_segment_assign'
require 'actions/isolation_segment_unassign'
require 'actions/isolation_segment_update'
require 'actions/isolation_segment_delete'

require 'messages/isolation_segments/isolation_segment_relationship_org_message'
require 'messages/isolation_segments/isolation_segment_create_message'
require 'messages/isolation_segments/isolation_segment_update_message'
require 'messages/isolation_segments/isolation_segments_list_message'

require 'presenters/v3/isolation_segment_presenter'
require 'presenters/v3/relationship_presenter'
require 'presenters/v3/to_many_relationship_presenter'

require 'fetchers/isolation_segment_list_fetcher'
require 'fetchers/isolation_segment_organizations_fetcher'
require 'fetchers/isolation_segment_spaces_fetcher'

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
    resource_not_found!(:isolation_segment) unless can_read_from_isolation_segment?(isolation_segment_model)

    render status: :ok, json: Presenters::V3::IsolationSegmentPresenter.new(isolation_segment_model)
  end

  def index
    message = IsolationSegmentsListMessage.from_params(query_params)
    invalid_param!(message.errors.full_messages) unless message.valid?

    fetcher = IsolationSegmentListFetcher.new(message: message)

    dataset = if can_read_globally?
                fetcher.fetch_all
              else
                fetcher.fetch_for_organizations(org_guids: readable_org_guids)
              end

    render status: :ok, json: Presenters::V3::PaginatedListPresenter.new(dataset: dataset, path: '/v3/isolation_segments', message: message)
  end

  def destroy
    unauthorized! unless roles.admin?

    isolation_segment_model = find_isolation_segment(params[:guid])
    IsolationSegmentDelete.new.delete(isolation_segment_model)

    head :no_content
  rescue IsolationSegmentDelete::AssociationNotEmptyError => e
    unprocessable!(e.message)
  end

  def update
    unauthorized! unless roles.admin?

    isolation_segment_model = find_isolation_segment(params[:guid])

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
    organizations = if can_read_globally?
                      fetcher.fetch_all
                    else
                      fetcher.fetch_for_organizations(org_guids: readable_org_guids)
                    end

    render status: :ok, json: Presenters::V3::ToManyRelationshipPresenter.new(
      "isolation_segments/#{isolation_segment_model.guid}", organizations, 'organizations')
  end

  def relationships_spaces
    isolation_segment_model = find_isolation_segment(params[:guid])
    resource_not_found!(:isolation_segment) unless can_read_from_isolation_segment?(isolation_segment_model)

    fetcher = IsolationSegmentSpacesFetcher.new(isolation_segment_model)
    spaces = if can_read_globally?
               fetcher.fetch_all
             else
               fetcher.fetch_for_spaces(space_guids: readable_space_guids)
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

    isolation_segment_model = IsolationSegmentModel.first(guid: params[:guid])
    resource_not_found!(:isolation_segment) unless isolation_segment_model

    org = Organization.first(guid: params[:org_guid])
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
    isolation_segment_model = IsolationSegmentModel.first(guid: params[:guid])
    resource_not_found!(:isolation_segment) unless isolation_segment_model

    message = IsolationSegmentRelationshipOrgMessage.create_from_http_request(params[:body])
    unprocessable!(message.errors.full_messages) unless message.valid?

    organizations = Organization.where(guid: message.guids).all
    missing_guids = message.guids - organizations.map(&:guid)
    unless missing_guids.empty?
      guid_list = missing_guids.map { |g| "'#{g}'" }.join(', ')
      unprocessable!("Unable to entitle organizations [#{guid_list}] for the isolation segment. Ensure the organizations exist.")
    end

    [isolation_segment_model, organizations]
  end

  def can_list_organizations?(isolation_segment)
    can_read_globally? || isolation_segment.organizations.any? { |org| can_read_from_org?(org.guid) }
  end

  def find_isolation_segment(guid)
    isolation_segment = IsolationSegmentModel.first(guid: guid)
    resource_not_found!(:isolation_segment) unless isolation_segment
    isolation_segment
  end
end
