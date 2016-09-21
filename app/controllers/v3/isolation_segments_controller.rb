require 'messages/isolation_segment_assign_org_message'
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
    isolation_segment_model = IsolationSegmentModel.where(guid: params[:guid]).first
    resource_not_found!(:isolation_segment) unless isolation_segment_model && (
      roles.admin? || 
      isolation_segment_model.spaces.any? { |space| can_read?(space.guid, space.organization.guid) } ||
      isolation_segment_model.organizations.any? { |org| can_read_from_org?(org.guid) }
    )

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

    method_not_allowed!('DELETE', 'the shared isolation segment') if params[:guid].eql?(VCAP::CloudController::IsolationSegmentModel::SHARED_ISOLATION_SEGMENT_GUID)

    isolation_segment_model = IsolationSegmentModel.where(guid: params[:guid]).first
    resource_not_found!(:isolation_segment) unless isolation_segment_model

    isolation_segment_model.db.transaction do
      isolation_segment_model.lock!
      isolation_segment_model.destroy
    end

    head :no_content
  end

  def update
    unauthorized! unless roles.admin?

    method_not_allowed!('PUT', 'the shared isolation segment') if params[:guid].eql?(VCAP::CloudController::IsolationSegmentModel::SHARED_ISOLATION_SEGMENT_GUID)

    message = IsolationSegmentCreateMessage.create_from_http_request(params[:body])
    unprocessable!(message.errors.full_messages) unless message.valid?

    isolation_segment_model = IsolationSegmentModel.where(guid: params[:guid]).first
    resource_not_found!(:isolation_segment) unless isolation_segment_model

    isolation_segment_model.db.transaction do
      isolation_segment_model.lock!
      isolation_segment_model.name = message.name if message.requested?(:name)
      isolation_segment_model.save
    end

    isolation_segment_model.reload

    render status: :ok, json: Presenters::V3::IsolationSegmentPresenter.new(isolation_segment_model)
  rescue Sequel::ValidationFailed => e
    unprocessable!(e.message)
  end

  def relationships_orgs
    isolation_segment_model = IsolationSegmentModel.where(guid: params[:guid]).first
    resource_not_found!(:isolation_segment) unless isolation_segment_model && (
      roles.admin? || 
      isolation_segment_model.organizations.any? { |org| can_read_from_org?(org.guid) }
    )

    fetcher = IsolationSegmentOrganizationsFetcher.new(isolation_segment_model)
    organizations = if roles.admin? || roles.admin_read_only?
                fetcher.fetch_all
              else
                fetcher.fetch_for_organizations(org_guids: readable_org_guids)
              end

    render status: :ok, json: Presenters::V3::RelationshipPresenter.new(organizations)
  end

  def relationships_spaces
    isolation_segment_model = IsolationSegmentModel.where(guid: params[:guid]).first
    resource_not_found!(:isolation_segment) unless isolation_segment_model && (
      roles.admin? || 
      isolation_segment_model.spaces.any? { |space| can_read?(space.guid, space.organization.guid) } ||
      isolation_segment_model.organizations.any? { |org| can_read_from_org?(org.guid) }
    )

    fetcher = IsolationSegmentSpacesFetcher.new(isolation_segment_model)
    spaces = if roles.admin? || roles.admin_read_only?
                fetcher.fetch_all
              else
                fetcher.fetch_for_spaces(space_guids: readable_space_guids)
              end
              
    render status: :ok, json: Presenters::V3::RelationshipPresenter.new(spaces)
  end

  def assign_allowed_organizations
    unauthorized! unless roles.admin?
    isolation_segment_model, orgs = assign_helper

    isolation_segment_model.db.transaction do
      isolation_segment_model.lock!
      orgs.each do |org|
        isolation_segment_model.add_organization(org)
      end
    end

    render status: :created, json: Presenters::V3::IsolationSegmentPresenter.new(isolation_segment_model)
  end

  def unassign_allowed_organizations
    unauthorized! unless roles.admin?
    isolation_segment_model, orgs = assign_helper

    isolation_segment_model.db.transaction do
      isolation_segment_model.lock!
      orgs.each do |org|
        isolation_segment_model.remove_organization(org)
      end
    end

    head :no_content
  end

  private

  def assign_helper
    isolation_segment_model = IsolationSegmentModel.where(guid: params[:guid]).first
    resource_not_found!(:isolation_segment) unless isolation_segment_model

    message = IsolationSegmentAssignOrgMessage.create_from_http_request(params[:body])
    unprocessable!(message.errors.full_messages) unless message.valid?

    organizations = Organization.where(guid: message.guids).all
    invalid_request!("Organization guids: #{message.guids - organizations.map { |org| org.guid } } cannot be found") unless organizations.length == message.guids.length

    [isolation_segment_model, organizations]
  end

  def filter(message, dataset)
    if message.requested?(:names)
      dataset = dataset.where(name: message.names)
    end
    if message.requested?(:guids)
      dataset = dataset.where(guid: message.guids)
    end
    dataset
  end
end
