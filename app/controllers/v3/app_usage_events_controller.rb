require 'presenters/v3/app_usage_event_presenter'
require 'messages/app_usage_events_list_message'
require 'fetchers/app_usage_event_list_fetcher'

class AppUsageEventsController < ApplicationController
  def index
    message = AppUsageEventsListMessage.from_params(query_params)
    unprocessable!(message.errors.full_messages) unless message.valid?

    app_usage_events = AppUsageEvent.where(guid: [])

    app_usage_events = AppUsageEventListFetcher.fetch_all(message, AppUsageEvent.dataset) if permission_queryer.can_read_globally?

    if message.consumer_guid && message.after_guid&.first && permission_queryer.can_write_globally?
      begin
        consumer = AppUsageConsumer.find_or_create(consumer_guid: message.consumer_guid) do |c|
          c.last_processed_guid = message.after_guid.first
        end

        consumer.update(last_processed_guid: message.after_guid.first) if !consumer.new? && consumer.last_processed_guid != message.after_guid.first
      rescue Sequel::ValidationFailed => e
        unprocessable!(e.message)
      rescue Sequel::Error
        error!('Failed to update consumer tracking', 500)
      end
    end

    render status: :ok, json: Presenters::V3::PaginatedListPresenter.new(
      presenter: Presenters::V3::AppUsageEventPresenter,
      paginated_result: SequelPaginator.new.get_page(app_usage_events, message.try(:pagination_options)),
      path: '/v3/app_usage_events',
      message: message
    )
  end

  def show
    app_usage_event_not_found! unless permission_queryer.can_read_globally?
    app_usage_event = AppUsageEvent.first(guid: hashed_params[:guid])
    app_usage_event_not_found! unless app_usage_event

    render status: :ok, json: Presenters::V3::AppUsageEventPresenter.new(app_usage_event)
  end

  def destructively_purge_all_and_reseed
    unauthorized! unless permission_queryer.can_write_globally?

    Repositories::AppUsageEventRepository.new.purge_and_reseed_started_apps!
    render status: :ok, json: {}
  end

  private

  def app_usage_event_not_found!
    resource_not_found!(:app_usage_event)
  end
end
