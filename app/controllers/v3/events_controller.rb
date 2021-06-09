require 'messages/events_list_message'
require 'fetchers/event_list_fetcher'
require 'presenters/v3/event_presenter'

class EventsController < ApplicationController
  def index
    message = EventsListMessage.from_params(query_params)
    invalid_param!(message.errors.full_messages) unless message.valid?

    dataset = EventListFetcher.fetch_all(message, permission_queryer.readable_event_dataset)

    render status: :ok, json: Presenters::V3::PaginatedListPresenter.new(
      presenter: Presenters::V3::EventPresenter,
      paginated_result: SequelPaginator.new.get_page(dataset, message.try(:pagination_options)),
      path: '/v3/audit_events',
      message: message,
    )
  end

  def show
    event = permission_queryer.readable_event_dataset.first(guid: hashed_params[:guid])
    event_not_found! unless event

    render status: :ok, json: Presenters::V3::EventPresenter.new(event)
  end

  private

  def event_not_found!
    resource_not_found!(:event)
  end
end
