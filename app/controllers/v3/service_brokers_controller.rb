require 'messages/service_brokers_list_message'
require 'messages/service_broker_create_message'
require 'messages/service_broker_update_message'
require 'presenters/v3/service_broker_presenter'
require 'fetchers/service_broker_list_fetcher'
require 'actions/service_broker_create'
require 'actions/v3/service_broker_update'

class ServiceBrokersController < ApplicationController
  def index
    message = ServiceBrokersListMessage.from_params(query_params)
    invalid_param!(message.errors.full_messages) unless message.valid?

    dataset = if permission_queryer.can_read_globally?
                ServiceBrokerListFetcher.fetch(
                  message: message,
                  eager_loaded_associations: Presenters::V3::ServiceBrokerPresenter.associated_resources,
                )
              else
                ServiceBrokerListFetcher.fetch(
                  message: message,
                  eager_loaded_associations: Presenters::V3::ServiceBrokerPresenter.associated_resources,
                  permitted_space_guids: permission_queryer.readable_services_space_guids
                )
              end

    presenter = Presenters::V3::PaginatedListPresenter.new(
      presenter: Presenters::V3::ServiceBrokerPresenter,
      paginated_result: SequelPaginator.new.get_page(dataset, message.try(:pagination_options)),
      message: message,
      path: '/v3/service_brokers',
    )

    render status: :ok, json: presenter.to_json
  end

  def show
    service_broker = VCAP::CloudController::ServiceBroker.find(guid: hashed_params[:guid])
    broker_not_found! unless service_broker

    if service_broker.space_guid
      space = service_broker.space
      broker_not_found! unless space && permission_queryer.can_read_services_in_space?(space.id, space.organization_id)
    else
      broker_not_found! unless permission_queryer.can_read_globally?
    end

    presenter = Presenters::V3::ServiceBrokerPresenter.new(service_broker)

    render status: :ok, json: presenter.to_json
  end

  def create
    message = ServiceBrokerCreateMessage.new(hashed_params[:body])
    unprocessable!(message.errors.full_messages) unless message.valid?

    if message.space_guid
      FeatureFlag.raise_unless_enabled!(:space_scoped_private_broker_creation)
      space = Space.where(guid: message.space_guid).first
      unprocessable_space! unless space && permission_queryer.can_read_from_space?(space.id, space.organization_id)
      unauthorized! unless permission_queryer.can_write_to_active_space?(space.id)
      suspended! unless permission_queryer.is_space_active?(space.id)
    else
      unauthorized! unless permission_queryer.can_write_globally?
    end

    service_broker_create = VCAP::CloudController::V3::ServiceBrokerCreate.new(service_event_repository)
    result = service_broker_create.create(message)

    head :accepted, 'Location' => url_builder.build_url(path: "/v3/jobs/#{result[:pollable_job].guid}")
  rescue VCAP::CloudController::V3::ServiceBrokerCreate::InvalidServiceBroker => e
    unprocessable!(e.message)
  end

  def update
    message = ServiceBrokerUpdateMessage.new(hashed_params[:body])
    unprocessable!(message.errors.full_messages) unless message.valid?

    service_broker = VCAP::CloudController::ServiceBroker.find(guid: hashed_params[:guid])
    broker_not_found! unless service_broker

    if service_broker.space_guid
      space = service_broker.space
      broker_not_found! unless space && permission_queryer.can_read_from_space?(space.id, space.organization_id)
      unauthorized! unless permission_queryer.can_write_to_active_space?(space.id)
      suspended! unless permission_queryer.is_space_active?(space.id)
    else
      broker_not_found! unless permission_queryer.can_read_globally?
      unauthorized! unless permission_queryer.can_write_globally?
    end

    service_broker_update = VCAP::CloudController::V3::ServiceBrokerUpdate.new(service_broker, message, service_event_repository)

    if service_broker_update.update_broker_needed?
      job = service_broker_update.enqueue_update
      head :accepted, 'Location' => url_builder.build_url(path: "/v3/jobs/#{job.guid}")
    else
      service_broker_update.update_sync
      render status: :ok, json: Presenters::V3::ServiceBrokerPresenter.new(service_broker).to_json
    end
  rescue VCAP::CloudController::V3::ServiceBrokerUpdate::InvalidServiceBroker => e
    unprocessable!(e.message)
  end

  def destroy
    service_broker = VCAP::CloudController::ServiceBroker.find(guid: hashed_params[:guid])
    broker_not_found! unless service_broker

    if service_broker.space.nil?
      broker_not_found! unless permission_queryer.can_read_globally?
      unauthorized! unless permission_queryer.can_write_globally?
    else
      broker_not_found! unless permission_queryer.can_read_from_space?(service_broker.space.id, service_broker.space.organization_id)
      unauthorized! unless permission_queryer.can_write_to_active_space?(service_broker.space.id)
      suspended! unless permission_queryer.is_space_active?(service_broker.space.id)
    end

    broker_has_instances!(service_broker.name) if service_broker.has_service_instances?

    service_event_repository = VCAP::CloudController::Repositories::ServiceEventRepository.new(user_audit_info)
    delete_action = VCAP::Services::ServiceBrokers::ServiceBrokerRemover.new(service_event_repository)
    deletion_job = VCAP::CloudController::Jobs::DeleteActionJob.new(ServiceBroker, service_broker.guid, delete_action)

    service_broker.update(state: ServiceBrokerStateEnum::DELETE_IN_PROGRESS)
    pollable_job = Jobs::Enqueuer.new(deletion_job, queue: Jobs::Queues.generic).enqueue_pollable

    head :accepted, 'Location' => url_builder.build_url(path: "/v3/jobs/#{pollable_job.guid}")
  end

  private

  def service_event_repository
    VCAP::CloudController::Repositories::ServiceEventRepository.new(user_audit_info)
  end

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
