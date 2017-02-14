require 'presenters/v3/paginated_list_presenter'
require 'messages/spaces/spaces_list_message'
require 'messages/spaces/space_update_message'
require 'actions/space_update'
require 'fetchers/space_list_fetcher'
require 'presenters/v3/paginated_list_presenter'

class SpacesV3Controller < ApplicationController
  def index
    message = SpacesListMessage.from_params(query_params)
    invalid_param!(message.errors.full_messages) unless message.valid?

    render status: :ok, json: Presenters::V3::PaginatedListPresenter.new(
      dataset: readable_spaces(message: message),
      path: '/v3/spaces',
      message: message
    )
  end

  def update
    space = Space.where(guid: params[:guid]).first
    resource_not_found!(:space) unless space

    org = space.organization
    resource_not_found!(:org) unless org
    resource_not_found!(:space) unless can_read?(space.guid, org.guid)
    unauthorized! unless can_write?(space.guid)

    message = SpaceUpdateMessage.create_from_http_request(params[:body])
    unprocessable!(message.errors.full_messages) unless message.valid?

    iso_seg_guid = message.isolation_segment_guid
    if iso_seg_guid
      isolation_segment = IsolationSegmentModel.where(guid: iso_seg_guid).first
      unprocessable_iso_seg(iso_seg_guid) unless isolation_segment && can_read_isolation_segment?(isolation_segment)

      entitled_iso_segs = org.isolation_segment_guids
      unprocessable_iso_seg(iso_seg_guid) unless entitled_iso_segs.include?(iso_seg_guid)

      SpaceUpdate.new(user_audit_info).update(space, isolation_segment, message)
    else
      SpaceUpdate.new(user_audit_info).update(space, nil, message)
    end

    render status: :ok, json: Presenters::V3::OneToOneRelationshipPresenter.new("spaces/#{space.guid}", isolation_segment, 'isolation_segment')
  rescue SpaceUpdate::InvalidSpace => e
    unprocessable!(e.message)
  end

  def index_isolation_segment
    space = Space.where(guid: params[:guid]).first
    isolation_segment = IsolationSegmentModel.where(guid: space.isolation_segment_guid).first
    render status: :ok, json: Presenters::V3::OneToOneRelationshipPresenter.new("spaces/#{space.guid}", isolation_segment, 'isolation_segment')
  end

  private

  def unprocessable_iso_seg(iso_seg_guid)
    raise CloudController::Errors::ApiError.new_from_details('UnprocessableEntity',
      "Unable to set #{iso_seg_guid} as the isolation segment. Ensure it has been entitled to the organization that this space belongs to.")
  end

  def readable_spaces(message:)
    if can_read_globally?
      SpaceListFetcher.new.fetch_all(message: message)
    else
      SpaceListFetcher.new.fetch(message: message, guids: readable_space_guids)
    end
  end
end
