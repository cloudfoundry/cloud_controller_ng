module VCAP::Services::ServiceBrokers::V2
  class Catalog
    attr_reader :service_broker, :services, :plans, :errors, :incompatibility_errors

    alias_method :validation_errors, :errors

    def initialize(service_broker, catalog_hash)
      @service_broker = service_broker
      @services = []
      @plans = []
      @errors = VCAP::Services::ValidationErrors.new
      @incompatibility_errors = VCAP::Services::ValidationErrors.new

      catalog_hash.fetch('services', []).each do |service_attrs|
        service = CatalogService.new(service_broker, service_attrs)
        @services << service
        @plans += service.plans
      end
    end

    def valid?
      validate_services
      validate_all_service_ids_are_unique
      validate_all_service_names_are_unique
      validate_all_service_dashboard_clients_are_unique
      validation_errors.empty?
    end

    def compatible?
      services.each { |service|
        if service.route_service? && route_services_disabled?
          incompatibility_errors.add("Service #{service.name} is declared to be a route service but support for route services is disabled.")
        end

        if service.volume_mount_service? && volume_services_disabled?
          incompatibility_errors.add("Service #{service.name} is declared to be a volume mount service but support for volume mount services is disabled.")
        end
      }
      incompatibility_errors.empty?
    end

    private

    def validate_all_service_dashboard_clients_are_unique
      dashboard_clients = valid_dashboard_clients(services)
      dashboard_client_ids = valid_dashboard_client_ids(dashboard_clients)
      if has_duplicates?(dashboard_client_ids)
        validation_errors.add('Service dashboard_client id must be unique')
      end
    end

    def valid_dashboard_client_ids(clients)
      clients.map { |client| client['id'] }.compact
    end

    def valid_dashboard_clients(services)
      services.map(&:dashboard_client).select { |client| client.is_a? Hash }
    end

    def validate_all_service_ids_are_unique
      if has_duplicates?(services.map(&:broker_provided_id).compact)
        validation_errors.add('Service ids must be unique')
      end
    end

    def validate_all_service_names_are_unique
      if has_duplicates?(services.map(&:name))
        validation_errors.add('Service names must be unique within a broker')
      end
    end

    def has_duplicates?(array)
      array.uniq.count < array.count
    end

    def validate_services
      services.each do |service|
        validation_errors.add_nested(service, service.errors) unless service.valid?
      end

      validation_errors.add('Service broker must provide at least one service') if services.empty?
    end

    def volume_services_disabled?
      !VCAP::CloudController::Config.config.get(:volume_services_enabled)
    end

    def route_services_disabled?
      !VCAP::CloudController::Config.config.get(:route_services_enabled)
    end
  end
end
