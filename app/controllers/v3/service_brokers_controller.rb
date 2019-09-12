require 'messages/service_brokers_list_message'
require 'messages/service_broker_create_message'
require 'presenters/v3/service_broker_presenter'
require 'fetchers/service_broker_list_fetcher'
require 'actions/service_broker_create'

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

  def create
    message = ServiceBrokerCreateMessage.new(hashed_params[:body])
    unprocessable!(message.errors.full_messages) unless message.valid?

    if message.space_guid
      space = Space.where(guid: message.space_guid).first
      unprocessable_space! unless space && permission_queryer.can_read_from_space?(space.guid, space.organization_guid)
      unauthorized! unless permission_queryer.can_write_space_scoped_service_broker?(space.guid)
    else
      unauthorized! unless permission_queryer.can_write_global_service_broker?
    end

    service_event_repository = VCAP::CloudController::Repositories::ServiceEventRepository::WithBrokerActor.new
    service_manager = VCAP::Services::ServiceBrokers::ServiceManager.new(service_event_repository)
    service_broker_create = VCAP::CloudController::V3::ServiceBrokerCreate.new(service_event_repository, service_manager)

    result = service_broker_create.create(message)

    add_warning_headers(result[:warnings])
    render status: :created, json: {}
  rescue VCAP::CloudController::V3::ServiceBrokerCreate::InvalidServiceBroker => e
    unprocessable!(e.message)
  end

  def destroy
    service_broker = VCAP::CloudController::ServiceBroker.find(guid: hashed_params[:guid])
    broker_not_found! unless service_broker

    if service_broker.space.nil?
      broker_not_found! unless permission_queryer.can_read_globally?
      unauthorized! unless permission_queryer.can_write_global_service_broker?
    else
      broker_not_found! unless permission_queryer.can_read_from_space?(service_broker.space.guid, service_broker.space.organization.guid)
      unauthorized! unless permission_queryer.can_write_space_scoped_service_broker?(service_broker.space.guid)
    end

    broker_has_instances!(service_broker.name) if service_broker.has_service_instances?

    service_event_repository = VCAP::CloudController::Repositories::ServiceEventRepository.new(user_audit_info)
    service_broker_remover = VCAP::Services::ServiceBrokers::ServiceBrokerRemover.new(service_event_repository)

    service_broker_remover.remove(service_broker)
  end

  private

  def broker_has_instances!(broker_name)
    raise CloudController::Errors::V3::ApiError.new_from_details('ServiceBrokerNotRemovable', broker_name)
  end

  def broker_not_found!
    resource_not_found!(:service_broker)
  end

  def unprocessable_space!
    unprocessable!('Invalid space. Ensure that the space exists and you have access to it.')
  end
end
