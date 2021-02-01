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
      validate_all_plan_ids_are_unique
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
      new_services_names = services.map(&:name)
      if has_duplicates?(new_services_names)
        validation_errors.add('Service names must be unique within a broker')
      end

      if service_broker.exists?
        taken_names = taken_names(new_services_names)
        if !taken_names.empty?
          validation_errors.add("Service names must be unique within a broker. Services with names #{taken_names} already exist")
        end
      end
    end

    def validate_all_plan_ids_are_unique
      catalog_plans = {}
      services.each do |s|
        s.plans.each do |p|
          if catalog_plans[p.broker_provided_id]
            validation_errors.add('Plan ids must be unique. ' \
              "Unable to register plan with id '#{p.broker_provided_id}' " \
              "(plan name '#{p.name}', service name '#{s.name}') " \
              'because it uses the same id as another plan in the catalog ' \
              "(plan name '#{catalog_plans[p.broker_provided_id][:plan].name}', service name '#{catalog_plans[p.broker_provided_id][:service].name}')"
            )
          end
          catalog_plans[p.broker_provided_id] = { service: s, plan: p }
        end
      end

      service_broker.service_plans.each do |p|
        if catalog_plans[p.unique_id] && !updating_service?(catalog_plans[p.unique_id][:service], p.service)
          validation_errors.add('Plan ids must be unique. ' \
                  "Unable to register plan with id '#{p.unique_id}' " \
                  "(plan name '#{catalog_plans[p.unique_id][:plan].name}', " \
                  "service name '#{catalog_plans[p.unique_id][:service].name}') " \
                  'because it uses the same id as an existing plan ' \
                  "(plan name '#{p.name}', " \
                  "service name '#{p.service.name}', " \
                  "broker name '#{p.service_broker.name}')"
          )
        end
      end
    end

    def taken_names(new_services_names)
      clashing_names = []
      clashing_services = service_broker.services_dataset.where(label: new_services_names)
      clashing_services.each do |old_service|
        new_service = services.detect { |ns| ns.name == old_service.name }
        next if updating_service?(new_service, old_service)

        clashing_names << new_service.name if !can_delete_service?(old_service)
      end
      clashing_names
    end

    def can_delete_service?(service)
      service.service_plans_dataset.map(&:service_instances_dataset).map(&:count).all?(0)
    end

    def updating_service?(new_service, old_service)
      new_service.broker_provided_id == old_service.unique_id
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
