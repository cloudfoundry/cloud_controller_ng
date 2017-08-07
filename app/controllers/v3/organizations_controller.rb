require 'presenters/v3/paginated_list_presenter'
require 'messages/orgs/organization_create_message'
require 'messages/orgs/orgs_list_message'
require 'presenters/v3/to_one_relationship_presenter'
require 'messages/orgs/orgs_default_iso_seg_update_message'
require 'fetchers/org_list_fetcher'
require 'actions/set_default_isolation_segment'
require 'controllers/v3/mixins/sub_resource'

class OrganizationsV3Controller < ApplicationController
  include SubResource

  def show
    org = fetch_org(params[:guid])
    org_not_found! unless org && can_read_from_org?(org.guid)

    render status: :ok, json: Presenters::V3::OrganizationPresenter.new(org)
  end

  def index
    message = OrgsListMessage.from_params(subresource_query_params)
    invalid_param!(message.errors.full_messages) unless message.valid?

    dataset = if isolation_segment_nested?
                fetch_orgs_for_isolation_segment(message)
              else
                fetch_orgs(message)
              end

    render status: :ok, json: Presenters::V3::PaginatedListPresenter.new(
      dataset: dataset,
      path: base_url(resource: 'organizations'),
      message: message
    )
  end

  def create
    unauthorized! unless can_write_globally? || user_org_creation_enabled?

    message = VCAP::CloudController::OrganizationCreateMessage.create_from_http_request(params[:body])
    unprocessable!(message.errors.full_messages) unless message.valid?

    org = Organization.create(name: message.name)

    render json: Presenters::V3::OrganizationPresenter.new(org), status: :created
  rescue Sequel::ValidationFailed => e
    if e.errors.on(:name)&.include?(:unique)
      unprocessable!('Name must be unique')
    end
    unprocessable!(e.message)
  end

  def show_default_isolation_segment
    org = fetch_org(params[:guid])
    org_not_found! unless org && can_read_from_org?(org.guid)

    isolation_segment = fetch_isolation_segment(org.default_isolation_segment_guid)

    render status: :ok, json: Presenters::V3::ToOneRelationshipPresenter.new(
      resource_path: "organizations/#{org.guid}",
      related_instance: isolation_segment,
      relationship_name: 'default_isolation_segment',
      related_resource_name: 'isolation_segments'
    )
  end

  def update_default_isolation_segment
    message = OrgDefaultIsoSegUpdateMessage.create_from_http_request(unmunged_body)
    unprocessable!(message.errors.full_messages) unless message.valid?

    org = fetch_org(params[:guid])
    org_not_found! unless org && can_read_from_org?(org.guid)
    unauthorized! unless roles.admin? || org.managers.include?(current_user)
    iso_seg_guid = message.default_isolation_segment_guid
    isolation_segment = fetch_isolation_segment(iso_seg_guid)

    SetDefaultIsolationSegment.new.set(org, isolation_segment, message)

    render status: :ok, json: Presenters::V3::ToOneRelationshipPresenter.new(
      resource_path: "organizations/#{org.guid}",
      related_instance: isolation_segment,
      relationship_name: 'default_isolation_segment',
      related_resource_name: 'isolation_segments'
    )
  rescue SetDefaultIsolationSegment::Error => e
    unprocessable!(e.message)
  end

  private

  def user_org_creation_enabled?
    VCAP::CloudController::FeatureFlag.enabled?(:user_org_creation)
  end

  def org_not_found!
    resource_not_found!(:organization)
  end

  def isolation_segment_not_found!
    resource_not_found!(:isolation_segment)
  end

  def fetch_org(guid)
    Organization.where(guid: guid).first
  end

  def fetch_isolation_segment(guid)
    IsolationSegmentModel.where(guid: guid).first
  end

  def fetch_orgs(message)
    if can_read_globally?
      OrgListFetcher.new.fetch_all(message: message)
    else
      OrgListFetcher.new.fetch(message: message, guids: readable_org_guids)
    end
  end

  def fetch_orgs_for_isolation_segment(message)
    if can_read_globally?
      isolation_segment, dataset = OrgListFetcher.new.fetch_all_for_isolation_segment(message: message)
    else
      isolation_segment, dataset = OrgListFetcher.new.fetch_for_isolation_segment(message: message, guids: readable_org_guids)
    end
    isolation_segment_not_found! unless isolation_segment && can_read_from_isolation_segment?(isolation_segment)
    dataset
  end
end
