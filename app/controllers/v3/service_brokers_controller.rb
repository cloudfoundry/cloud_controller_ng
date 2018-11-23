require 'messages/service_brokers_list_message'
require 'presenters/v3/service_broker_presenter'
require 'fetchers/service_broker_list_fetcher'

class ServiceBrokersController < ApplicationController
  def index
    message = ServiceBrokersListMessage.from_params(query_params)
    invalid_param!(message.errors.full_messages) unless message.valid?

    dataset = if permission_queryer.can_read_globally?
                ServiceBrokerListFetcher.new.fetch(message)
              else
                ServiceBrokerListFetcher.new.fetch(message, permission_queryer.space_developer_space_guids)
              end

    render status: :ok,
           json: Presenters::V3::PaginatedListPresenter.new(
             presenter: Presenters::V3::ServiceBrokerPresenter,
             paginated_result: SequelPaginator.new.get_page(dataset, message.try(:pagination_options)),
             path: '/v3/service_brokers',
          )
  end
end
