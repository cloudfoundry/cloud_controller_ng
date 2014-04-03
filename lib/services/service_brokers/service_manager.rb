module VCAP::Services::ServiceBrokers
  class ServiceManager
    attr_reader :catalog

    def initialize(catalog)
      @catalog = catalog
    end

    def sync_services_and_plans
      update_or_create_services
      deactivate_services
      update_or_create_plans
      deactivate_plans
      delete_plans
      delete_services
    end

    private

    def update_or_create_services
      catalog.services.each do |catalog_service|
        service_id = catalog_service.broker_provided_id

        VCAP::CloudController::Service.update_or_create(
          service_broker: catalog.service_broker,
          unique_id:      service_id
        ) do |service|
          service.set(
            label:       catalog_service.name,
            description: catalog_service.description,
            bindable:    catalog_service.bindable,
            tags:        catalog_service.tags,
            extra:       catalog_service.metadata ? catalog_service.metadata.to_json : nil,
            active:      catalog_service.plans_present?,
            requires:    catalog_service.requires,
          )
        end
      end
    end

    def deactivate_services
      services_in_db_not_in_catalog = catalog.service_broker.services_dataset.where('unique_id NOT in ?', catalog.services.map(&:broker_provided_id))
      services_in_db_not_in_catalog.each do |service|
        service.update(active: false)
      end
    end

    def update_or_create_plans
      catalog.plans.each do |catalog_plan|
        attrs = {
          name:        catalog_plan.name,
          description: catalog_plan.description,
          free:        catalog_plan.free,
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
      plan_ids_in_broker_catalog = catalog.plans.map(&:broker_provided_id)
      plans_in_db_not_in_catalog = catalog.service_broker.service_plans.reject { |p| plan_ids_in_broker_catalog.include?(p.broker_provided_id) }
      plans_in_db_not_in_catalog.each do |plan_to_deactivate|
        plan_to_deactivate.active = false
        plan_to_deactivate.save
      end
    end

    def delete_plans
      plan_ids_in_broker_catalog = catalog.plans.map(&:broker_provided_id)
      plans_in_db_not_in_catalog = catalog.service_broker.service_plans.reject { |p| plan_ids_in_broker_catalog.include?(p.broker_provided_id) }
      plans_in_db_not_in_catalog.each do |plan_to_deactivate|
        if plan_to_deactivate.service_instances.count < 1
          plan_to_deactivate.destroy
        end
      end
    end

    def delete_services
      services_in_db_not_in_catalog = catalog.service_broker.services_dataset.where('unique_id NOT in ?', catalog.services.map(&:broker_provided_id))
      services_in_db_not_in_catalog.each do |service|
        if service.service_plans.count < 1
          service.destroy
        end
      end
    end
  end
end
