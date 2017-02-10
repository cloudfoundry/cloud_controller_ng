require 'presenters/v3/paginated_list_presenter'
require 'messages/spaces/spaces_list_message'
require 'actions/space_update'
require 'messages/space_update_message'
require 'fetchers/space_list_fetcher'

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

    if message.isolation_segment_guid
      isolation_segment_model = IsolationSegmentModel.where(guid: message.isolation_segment_guid).first
      resource_not_found!(:isolation_segment) unless isolation_segment_model && can_read_isolation_segment?(isolation_segment_model)

      if !org_is_entitled(org, isolation_segment_model)
        raise CloudController::Errors::ApiError.new_from_details('UnprocessableEntity',
          "Unable to set '#{isolation_segment_model.guid}' as the isolation segment. Ensure it has been entitled to organization '#{org.name}'.")
      end

      SpaceUpdate.new(user_audit_info).update(space, isolation_segment_model, message)
    else
      SpaceUpdate.new(user_audit_info).update(space, nil, message)
    end

    render status: :ok, json: Presenters::V3::OneToOneRelationshipPresenter.new("spaces/#{space.guid}", isolation_segment_model, 'isolation_segment')
  end

  private

  def org_is_entitled(org, isolation_segment_model)
    org.isolation_segment_models.map(&:guid).include?(isolation_segment_model.guid)
  end

  def readable_spaces(message:)
    if can_read_globally?
      SpaceListFetcher.new.fetch_all(message: message)
    else
      SpaceListFetcher.new.fetch(message: message, guids: readable_space_guids)
    end
  end
end
