module VCAP::Services::ServiceBrokers::V2
  class Catalog
    attr_reader :service_broker, :services, :plans, :errors

    def initialize(service_broker, catalog_hash)
      @service_broker = service_broker
      @services       = []
      @plans          = []
      @errors         = VCAP::Services::ValidationErrors.new

      catalog_hash.fetch('services', []).each do |service_attrs|
        service = CatalogService.new(service_broker, service_attrs)
        @services << service
        @plans += service.plans
      end
    end

    def valid?
      validate_services
      validate_all_service_ids_are_unique
      validate_all_service_dashboard_clients_are_unique
      errors.empty?
    end

    private

    def validate_all_service_dashboard_clients_are_unique
      dashboard_clients = valid_dashboard_clients(services)
      dashboard_client_ids = valid_dashboard_client_ids(dashboard_clients)
      if has_duplicates?(dashboard_client_ids)
        errors.add('Service dashboard_client id must be unique')
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
        errors.add('Service ids must be unique')
      end
    end

    def has_duplicates?(array)
      array.uniq.count < array.count
    end

    def validate_services
      services.each do |service|
        errors.add_nested(service, service.errors) unless service.valid?
      end

      errors.add('Service broker must provide at least one service') if services.empty?
    end
  end
end
