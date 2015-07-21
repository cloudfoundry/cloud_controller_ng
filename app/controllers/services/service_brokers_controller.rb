require 'presenters/api/service_broker_presenter'
require 'actions/services/service_broker_create'
require 'actions/services/service_broker_update'

module VCAP::CloudController
  # This controller is an experiment breaking away from the old
  # cloudcontroller metaprogramming. We manually generate the JSON
  # expected by CFoundry and CF.
  class ServiceBrokersController < RestController::ModelController
    define_attributes do
      attribute :name,           String
      attribute :broker_url,     String
      attribute :auth_username,  String
      attribute :auth_password,  String
      attribute :space_guid,     String, default: nil, exclude_in: [:update]
    end

    query_parameters :name, :space_guid

    def self.dependencies
      [:service_manager, :services_event_repository]
    end

    def inject_dependencies(dependencies)
      super
      @service_manager = dependencies.fetch(:service_manager)
      @services_event_repository = dependencies.fetch(:services_event_repository)
    end

    def create
      params = CreateMessage.decode(body).extract

      create_action = ServiceBrokerCreate.new(
        @service_manager,
        @services_event_repository,
        self,
        self
      )

      broker = create_action.create(params)
      headers = { 'Location' => url_of(broker) }
      body = ServiceBrokerPresenter.new(broker).to_json

      [HTTP::CREATED, headers, body]
    rescue ServiceBrokerCreate::SpaceNotFound => e
      logger.error("Space not found: #{params[:space_guid]}, Vcap-Request-Id: #{VCAP::Request.current_id}, Error: #{e.message}")
      raise VCAP::Errors::ApiError.new_from_details('ResourceNotFound', 'Space not found')
    end

    def update(guid)
      validate_access(:update, ServiceBroker)
      update_action = ServiceBrokerUpdate.new(
        @service_manager,
        @services_event_repository,
        self
      )
      params = UpdateMessage.decode(body).extract
      broker = update_action.update(guid, params)
      return HTTP::NOT_FOUND unless broker
      body = ServiceBrokerPresenter.new(broker).to_json
      [HTTP::OK, {}, body]
    end

    def delete(guid)
      validate_access(:delete, ServiceBroker)
      broker = ServiceBroker.find(guid: guid)
      return HTTP::NOT_FOUND unless broker

      VCAP::Services::ServiceBrokers::ServiceBrokerRemover.new(broker, @services_event_repository).execute!
      @services_event_repository.record_broker_event(:delete, broker, {})

      HTTP::NO_CONTENT
    rescue Sequel::ForeignKeyConstraintViolation
      raise VCAP::Errors::ApiError.new_from_details('ServiceBrokerNotRemovable')
    end

    def self.translate_validation_exception(e, _)
      if e.errors.on(:name) && e.errors.on(:name).include?(:unique)
        Errors::ApiError.new_from_details('ServiceBrokerNameTaken', e.model.name)
      elsif e.errors.on(:broker_url) && e.errors.on(:broker_url).include?(:unique)
        Errors::ApiError.new_from_details('ServiceBrokerUrlTaken', e.model.broker_url)
      else
        Errors::ApiError.new_from_details('ServiceBrokerCatalogInvalid', e.errors.full_messages)
      end
    end

    define_messages
    define_routes

    private

    def url_of(broker)
      "#{self.class.path}/#{broker.guid}"
    end
  end
end
