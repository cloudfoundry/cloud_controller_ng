require 'presenters/v3/paginated_list_presenter'
require 'messages/spaces_list_message'
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

  private

  def readable_spaces(message:)
    if can_read_globally?
      SpaceListFetcher.new.fetch_all(message: message)
    else
      SpaceListFetcher.new.fetch(message: message, guids: readable_space_guids)
    end
  end
end
