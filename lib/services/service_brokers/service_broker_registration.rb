module VCAP::Services::ServiceBrokers
  class ServiceBrokerRegistration
    attr_reader :broker, :warnings

    def initialize(broker, service_manager, services_event_repository, route_services_enabled)
      @broker = broker
      @service_manager = service_manager
      @warnings = []
      @services_event_repository = services_event_repository
      @route_services_enabled = route_services_enabled
    end

    def create
      return unless broker.valid?
      validate_catalog!
      route_service_warning unless @route_services_enabled
      broker.save

      begin
        synchronize_dashboard_clients!

        broker.db.transaction do
          synchronize_services_and_plans!
        end
      rescue => e
        broker.destroy
        raise e
      end
      self
    end

    def update
      return unless broker.valid?

      if only_updating_broker_name?
        broker.save
        return self
      end

      validate_catalog!
      route_service_warning unless @route_services_enabled
      synchronize_dashboard_clients!

      broker.db.transaction do
        broker.save
        synchronize_services_and_plans!
      end
      self
    end

    def errors
      broker.errors
    end

    private

    def only_updating_broker_name?
      current_broker_values = VCAP::CloudController::ServiceBroker.find(guid: broker.guid).values.to_a
      update_values = current_broker_values - broker.values.to_a
      update_values.length == 1 && update_values[0][0] == :name
    end

    def synchronize_dashboard_clients!
      unless client_manager.synchronize_clients_with_catalog(catalog)
        raise_humanized_exception(client_manager.errors)
      end

      if client_manager.has_warnings?
        client_manager.warnings.each { |warning| warnings << warning }
      end
    end

    def synchronize_services_and_plans!
      @service_manager.sync_services_and_plans(catalog)

      if @service_manager.has_warnings?
        @service_manager.warnings.each { |warning| warnings << warning }
      end
    end

    def validate_catalog!
      raise_humanized_exception(catalog.errors) unless catalog.valid?
    end

    def client_manager
      @client_manager ||= VCAP::Services::SSO::DashboardClientManager.new(broker, @services_event_repository)
    end

    def catalog
      @catalog ||= VCAP::Services::ServiceBrokers::V2::Catalog.new(broker, broker.client.catalog)
    end

    def formatter
      @formatter ||= ValidationErrorsFormatter.new
    end

    def raise_humanized_exception(errors)
      humanized_message = formatter.format(errors)
      raise VCAP::Errors::ApiError.new_from_details('ServiceBrokerCatalogInvalid', humanized_message)
    end

    def route_service_warning
      catalog.services.each { |service|
        if service.route_service?
          @warnings << "Service #{service.name} is declared to be a route service but support for route services is disabled." \
                       ' Users will be prevented from binding instances of this service with routes.'
        end
      }
    end
  end
end
