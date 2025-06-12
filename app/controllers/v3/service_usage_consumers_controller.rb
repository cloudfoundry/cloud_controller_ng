require 'presenters/v3/service_usage_consumer_presenter'
require 'messages/service_usage_consumers_list_message'
require 'fetchers/service_usage_consumer_list_fetcher'
require 'actions/service_usage_consumer_delete'

class ServiceUsageConsumersController < ApplicationController
  def index
    message = ServiceUsageConsumersListMessage.from_params(query_params)
    invalid_param!(message.errors.full_messages) unless message.valid?

    service_usage_consumers = ServiceUsageConsumer.where(guid: [])

    service_usage_consumers = ServiceUsageConsumerListFetcher.fetch_all(message, ServiceUsageConsumer.dataset) if permission_queryer.can_read_globally?

    render status: :ok, json: Presenters::V3::PaginatedListPresenter.new(
      presenter: Presenters::V3::ServiceUsageConsumerPresenter,
      paginated_result: SequelPaginator.new.get_page(service_usage_consumers, message.try(:pagination_options)),
      path: '/v3/service_usage_consumers',
      message: message,
      extra_presenter_args: {}
    )
  end

  def show
    service_usage_consumer = ServiceUsageConsumer.where(consumer_guid: params[:guid]).first
    resource_not_found!(:service_usage_consumer) unless service_usage_consumer && permission_queryer.can_read_globally?

    render status: :ok, json: Presenters::V3::ServiceUsageConsumerPresenter.new(service_usage_consumer)
  end

  def destroy
    unauthorized! unless permission_queryer.can_write_globally?

    service_usage_consumer = ServiceUsageConsumer.where(consumer_guid: params[:guid]).first
    resource_not_found!(:service_usage_consumer) unless service_usage_consumer

    ServiceUsageConsumerDelete.new.delete(service_usage_consumer)

    head :no_content
  end
end
