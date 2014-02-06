require 'models/services/service_broker/v2'
require 'models/services/service_broker/v2/catalog_service'
require 'models/services/service_broker/v2/catalog_plan'
require 'models/services/service_broker/v2/service_dashboard_client_manager'
require 'vcap/errors'


module VCAP::CloudController::ServiceBroker::V2
  class Catalog
    attr_reader :service_broker, :services, :plans

    def initialize(service_broker, catalog_hash)
      @service_broker = service_broker
      @services       = []
      @plans          = []

      catalog_hash.fetch('services', []).each do |service_attrs|
        service = CatalogService.new(service_broker, service_attrs)
        @services << service
        @plans += service.plans
      end
    end

    def valid?
      @services.map(&:valid?).all?
    end

    INDENT = '  '.freeze
    def error_text
      message = "\n"
      @services.each do |service|
        next if service.valid?

        message += "Service #{service.name}\n"
        service.errors.each do |error|
          message += "#{INDENT}#{error}\n"
        end

        service.plans.each do |plan|
          next if plan.valid?

          message += "#{INDENT}Plan #{plan.name}\n"
          plan.errors.each do |error|
            message += "#{INDENT}#{INDENT}#{error}\n"
          end
        end
      end
      message
    end

    def sync_services_and_plans
      update_or_create_services
      deactivate_services
      update_or_create_plans
      deactivate_plans
      delete_plans
      delete_services
    end

    def create_service_dashboard_clients
      services_requesting_clients = services.find_all { |service| service.dashboard_client  }
      return unless services_requesting_clients.count > 0

      client_manager   = ServiceDashboardClientManager.new
      client_ids       = services_requesting_clients.map { |service| service.dashboard_client['id'] }
      existing_clients = client_manager.get_clients(client_ids)

      services_with_existing_clients = match_catalog_service_to_uaa_client(existing_clients, services_requesting_clients)
      services_needing_clients       = services_requesting_clients - services_with_existing_clients

      if (services_with_existing_clients.count > 0)
        validate_existing_clients_match_existing_services(services_with_existing_clients)
        raise VCAP::Errors::ServiceBrokerCatalogInvalid.new(error_text) unless valid?
      end

      services_needing_clients.each do |service|
        client_manager.create(service.dashboard_client)
      end
    end

    private

    def validate_existing_clients_match_existing_services(services_with_existing_clients)
      catalog_to_db_service_hash = map_catalog_to_db_service(services_with_existing_clients)

      catalog_to_db_service_hash.each do |catalog_service, db_service|
        # ensure that the service requesting the existing uaa client is the one that originally created it
        unless db_service && (db_service.dashboard_client_id == catalog_service.dashboard_client['id'])
          catalog_service.errors << 'Service dashboard client id must be unique'
        end
      end
    end

    def match_catalog_service_to_uaa_client(existing_clients, services_requesting_clients)
      existing_client_names = existing_clients.map { |client| client['client_id'] }

      services_requesting_clients.find_all do |service|
        existing_client_names.include?(service.dashboard_client['id'])
      end
    end

    def map_catalog_to_db_service(services_with_existing_clients)
      broker_provided_ids = services_with_existing_clients.map(&:broker_provided_id)
      services_from_db    = VCAP::CloudController::Service.where(:unique_id => broker_provided_ids).all
      ret_hash            = {}

      services_with_existing_clients.each do |catalog_service|
        ret_hash[catalog_service] = services_from_db.find { |service| service.unique_id == catalog_service.broker_provided_id }
      end
      ret_hash
    end

    def update_or_create_services
      services.each do |catalog_service|
        service_id = catalog_service.broker_provided_id
        dashboard_client_id = catalog_service.dashboard_client ?
            catalog_service.dashboard_client['id'] : nil

        VCAP::CloudController::Service.update_or_create(
          service_broker: service_broker,
          unique_id:      service_id
        ) do |service|
          service.set(
            label:       catalog_service.name,
            description: catalog_service.description,
            bindable:    catalog_service.bindable,
            tags:        catalog_service.tags,
            extra:       catalog_service.metadata ? catalog_service.metadata.to_json : nil,
            active:      catalog_service.plans_present?,
            dashboard_client_id: dashboard_client_id
          )
        end
      end
    end

    def deactivate_services
      services_in_db_not_in_catalog = VCAP::CloudController::Service.where('unique_id NOT in ?', services.map(&:broker_provided_id))
      services_in_db_not_in_catalog.each do |service|
        service.update(active: false)
      end
    end

    def update_or_create_plans
      plans.each do |catalog_plan|
        attrs = {
          name:        catalog_plan.name,
          description: catalog_plan.description,
          free:        true,
          active:      true,
          extra:       catalog_plan.metadata ? catalog_plan.metadata.to_json : nil
        }
        if catalog_plan.cc_plan
          catalog_plan.cc_plan.update(attrs)
        else
          VCAP::CloudController::ServicePlan.create(
            attrs.merge(
              service:   catalog_plan.catalog_service.cc_service,
              unique_id: catalog_plan.broker_provided_id,
              public:    false,
            )
          )
        end
      end
    end

    def deactivate_plans
      plan_ids_in_broker_catalog = plans.map(&:broker_provided_id)
      plans_in_db_not_in_catalog = service_broker.service_plans.reject { |p| plan_ids_in_broker_catalog.include?(p.broker_provided_id) }
      plans_in_db_not_in_catalog.each do |plan_to_deactivate|
        plan_to_deactivate.active = false
        plan_to_deactivate.save
      end
    end

    def delete_plans
      plan_ids_in_broker_catalog = plans.map(&:broker_provided_id)
      plans_in_db_not_in_catalog = service_broker.service_plans.reject { |p| plan_ids_in_broker_catalog.include?(p.broker_provided_id) }
      plans_in_db_not_in_catalog.each do |plan_to_deactivate|
        if plan_to_deactivate.service_instances.count < 1
          plan_to_deactivate.destroy
        end
      end
    end

    def delete_services
      services_in_db_not_in_catalog = VCAP::CloudController::Service.where('unique_id NOT in ?', services.map(&:broker_provided_id))
      services_in_db_not_in_catalog.each do |service|
        if service.service_plans.count < 1
          service.destroy
        end
      end
    end
  end
end
