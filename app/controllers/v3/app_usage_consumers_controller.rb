require 'presenters/v3/app_usage_consumer_presenter'
require 'messages/app_usage_consumers_list_message'
require 'fetchers/app_usage_consumer_list_fetcher'
require 'actions/app_usage_consumer_delete'

class AppUsageConsumersController < ApplicationController
  def index
    message = AppUsageConsumersListMessage.from_params(query_params)
    invalid_param!(message.errors.full_messages) unless message.valid?

    app_usage_consumers = AppUsageConsumer.where(guid: [])

    app_usage_consumers = AppUsageConsumerListFetcher.fetch_all(message, AppUsageConsumer.dataset) if permission_queryer.can_read_globally?

    render status: :ok, json: Presenters::V3::PaginatedListPresenter.new(
      presenter: Presenters::V3::AppUsageConsumerPresenter,
      paginated_result: SequelPaginator.new.get_page(app_usage_consumers, message.try(:pagination_options)),
      path: '/v3/app_usage_consumers',
      message: message,
      extra_presenter_args: {}
    )
  end

  def show
    app_usage_consumer = AppUsageConsumer.where(consumer_guid: params[:guid]).first
    resource_not_found!(:app_usage_consumer) unless app_usage_consumer && permission_queryer.can_read_globally?

    render status: :ok, json: Presenters::V3::AppUsageConsumerPresenter.new(app_usage_consumer)
  end

  def destroy
    unauthorized! unless permission_queryer.can_write_globally?

    app_usage_consumer = AppUsageConsumer.where(consumer_guid: params[:guid]).first
    resource_not_found!(:app_usage_consumer) unless app_usage_consumer

    AppUsageConsumerDelete.new.delete(app_usage_consumer)

    head :no_content
  end
end
