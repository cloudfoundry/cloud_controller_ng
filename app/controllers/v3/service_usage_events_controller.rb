require 'presenters/v3/service_usage_event_presenter'
require 'messages/service_usage_events_list_message'
require 'fetchers/service_usage_event_list_fetcher'

class ServiceUsageEventsController < ApplicationController
  def index
    message = ServiceUsageEventsListMessage.from_params(query_params)
    unprocessable!(message.errors.full_messages) unless message.valid?

    service_usage_events = ServiceUsageEvent.where(guid: [])

    service_usage_events = ServiceUsageEventListFetcher.fetch_all(message, ServiceUsageEvent.dataset) if permission_queryer.can_read_globally?

    if message.consumer_guid && message.after_guid&.first && permission_queryer.can_write_globally?
      begin
        consumer = ServiceUsageConsumer.find_or_create(consumer_guid: message.consumer_guid) do |c|
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
      presenter: Presenters::V3::ServiceUsageEventPresenter,
      paginated_result: SequelPaginator.new.get_page(service_usage_events, message.try(:pagination_options)),
      path: '/v3/service_usage_events',
      message: message
    )
  end

  def show
    service_usage_event_not_found! unless permission_queryer.can_read_globally?
    service_usage_event = ServiceUsageEvent.first(guid: hashed_params[:guid])
    service_usage_event_not_found! unless service_usage_event

    render status: :ok, json: Presenters::V3::ServiceUsageEventPresenter.new(service_usage_event)
  end

  def destructively_purge_all_and_reseed
    unauthorized! unless permission_queryer.can_write_globally?

    Repositories::ServiceUsageEventRepository.new.purge_and_reseed_service_instances!
    render status: :ok, json: {}
  end

  private

  def service_usage_event_not_found!
    resource_not_found!(:service_usage_event)
  end
end
