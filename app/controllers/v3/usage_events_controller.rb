require 'presenters/v3/usage_event_presenter'
require 'messages/usage_events_list_message'

class UsageEventsController < ApplicationController
  def show
    usage_event_not_found! unless permission_queryer.can_read_globally?
    usage_event = UsageEvent.first(guid: hashed_params[:guid])
    usage_event_not_found! unless usage_event

    render status: :ok, json: Presenters::V3::UsageEventPresenter.new(usage_event)
  end

  def index
    message = UsageEventsListMessage.from_params(query_params)

    # create an empty dataset
    usage_events = UsageEvent.where(guid: [])
    if permission_queryer.can_read_globally?
      usage_events = UsageEvent.dataset
    end

    render status: :ok, json: Presenters::V3::PaginatedListPresenter.new(
      presenter: Presenters::V3::UsageEventPresenter,
      paginated_result: SequelPaginator.new.get_page(usage_events, message.try(:pagination_options)),
      path: '/v3/usage_events',
    )
  end

  private

  def usage_event_not_found!
    resource_not_found!(:usage_event)
  end
end
