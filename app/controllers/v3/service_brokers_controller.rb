require 'messages/service_brokers_list_message'
require 'presenters/v3/service_broker_presenter'
require 'fetchers/service_broker_list_fetcher'

class ServiceBrokersController < ApplicationController
  def index
    message = ServiceBrokersListMessage.from_params(query_params)
    invalid_param!(message.errors.full_messages) unless message.valid?

    dataset = if permission_queryer.can_read_globally?
                ServiceBrokerListFetcher.new.fetch(message: message)
              else
                ServiceBrokerListFetcher.new.fetch(message: message, permitted_space_guids: permission_queryer.readable_secret_space_guids)
              end

    presenter = Presenters::V3::PaginatedListPresenter.new(
      presenter: Presenters::V3::ServiceBrokerPresenter,
      paginated_result: SequelPaginator.new.get_page(dataset, message.try(:pagination_options)),
      path: '/v3/service_brokers',
    )

    render status: :ok, json: presenter.to_json
  end

  def show
    service_broker = VCAP::CloudController::ServiceBroker.find(guid: hashed_params[:guid])

    broker_not_found! unless service_broker
    broker_not_found! unless permission_queryer.can_read_service_broker?(service_broker)

    presenter = Presenters::V3::ServiceBrokerPresenter.new(service_broker)

    render status: :ok, json: presenter.to_json
  end

  private

  def broker_not_found!
    resource_not_found!(:service_broker)
  end
end
