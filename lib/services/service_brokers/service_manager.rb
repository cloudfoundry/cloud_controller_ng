module VCAP::Services::ServiceBrokers
  class ServiceManager
    attr_reader :warnings

    def initialize(service_event_repository)
      @services_event_repository = service_event_repository
      @warnings = []
      @logger = Steno.logger('cc.service_broker.service_manager')
    end

    def sync_services_and_plans(catalog)
      update_or_create_services(catalog)
      deactivate_services(catalog)
      update_or_create_plans(catalog)
      deactivate_plans(catalog)
      delete_plans(catalog)
      delete_services(catalog)
    end

    def has_warnings?
      !warnings.empty?
    end

    private

    def update_or_create_services(catalog)
      existing_services, new_services = catalog.services.partition do |service|
        VCAP::CloudController::Service.where(
          service_broker: service.service_broker,
          unique_id: service.broker_provided_id
        ).present?
      end

      existing_services.each do |catalog_service|
        cond = {
          service_broker: catalog_service.service_broker,
          unique_id:      catalog_service.broker_provided_id,
        }
        service = VCAP::CloudController::Service.find(cond)
        update_service_from_catalog(service, catalog_service)
      end

      new_services.each do |catalog_service|
        service = VCAP::CloudController::Service.new(
          unique_id: catalog_service.broker_provided_id,
          service_broker: catalog_service.service_broker,
        )
        update_service_from_catalog(service, catalog_service)
      end
    end

    def update_or_create_plans(catalog)
      existing_plans, new_plans = catalog.plans.partition do |catalog_plan|
        VCAP::CloudController::ServicePlan.where(unique_id: catalog_plan.broker_provided_id,
                                                 service: catalog_plan.catalog_service.cc_service).present?
      end

      existing_plans.each do |catalog_plan|
        cond = {
          unique_id: catalog_plan.broker_provided_id,
          service: catalog_plan.catalog_service.cc_service,
        }
        plan = VCAP::CloudController::ServicePlan.find(cond)

        update_plan_from_catalog(plan, catalog_plan)
      end

      new_plans.each do |catalog_plan|
        plan = VCAP::CloudController::ServicePlan.new({
          unique_id: catalog_plan.broker_provided_id,
          service: catalog_plan.catalog_service.cc_service,
          public: false,
        })

        update_plan_from_catalog(plan, catalog_plan)
      end
    end

    def update_service_from_catalog(service, catalog_service)
      service.set(
        label:       catalog_service.name,
        description: catalog_service.description,
        bindable:    catalog_service.bindable,
        tags:        catalog_service.tags,
        extra:       catalog_service.metadata ? catalog_service.metadata.to_json : nil,
        active:      catalog_service.plans_present?,
        requires:    catalog_service.requires,
        plan_updateable: catalog_service.plan_updateable,
        bindings_retrievable: catalog_service.bindings_retrievable,
        instances_retrievable: catalog_service.instances_retrievable,
        allow_context_updates: catalog_service.allow_context_updates,
      )

      @services_event_repository.with_service_event(service) do
        service.save(changed: true)
      end
    end

    def update_plan_from_catalog(plan, catalog_plan)
      if catalog_plan.schemas
        schemas = catalog_plan.schemas
        create_instance = schemas.service_instance.try(:create).try(:parameters).try(:to_json)
        update_instance = schemas.service_instance.try(:update).try(:parameters).try(:to_json)
        create_binding = schemas.service_binding.try(:create).try(:parameters).try(:to_json)
      end

      plan.set({
        name:        catalog_plan.name,
        description: catalog_plan.description,
        free:        catalog_plan.free,
        bindable:    catalog_plan.bindable,
        active:      true,
        extra:       catalog_plan.metadata.try(:to_json),
        plan_updateable: catalog_plan.plan_updateable,
        maximum_polling_duration: catalog_plan.maximum_polling_duration,
        maintenance_info: catalog_plan.maintenance_info,
        create_instance_schema: create_instance,
        update_instance_schema: update_instance,
        create_binding_schema: create_binding,
      })
      @services_event_repository.with_service_plan_event(plan) do
        plan.save(changed: true)
      end
    end

    def find_or_new_model(model_class, cond)
      obj = model_class.first(cond)
      obj ||= model_class.new(cond)
      obj
    end

    def deactivate_services(catalog)
      services_in_db_not_in_catalog = catalog.service_broker.services_dataset.where(Sequel.lit('unique_id NOT in ?', catalog.services.map(&:broker_provided_id)))
      services_in_db_not_in_catalog.each do |service|
        service.update(active: false)
      end
    end

    def deactivate_plans(catalog)
      plan_ids_in_broker_catalog = catalog.plans.map(&:broker_provided_id)
      plans_in_db_not_in_catalog = catalog.service_broker.service_plans.reject { |p| plan_ids_in_broker_catalog.include?(p.broker_provided_id) }
      deactivated_plans_warning  = DeactivatedPlansWarning.new

      plans_in_db_not_in_catalog.each do |plan_to_deactivate|
        plan_to_deactivate.active = false
        plan_to_deactivate.save

        deactivated_plans_warning.add(plan_to_deactivate) if plan_to_deactivate.service_instances_dataset.count >= 1
      end

      @warnings << deactivated_plans_warning.message if deactivated_plans_warning.message
    end

    def delete_plans(catalog)
      plan_ids_in_broker_catalog = catalog.plans.map(&:broker_provided_id)
      plans_in_db_not_in_catalog = catalog.service_broker.service_plans.reject { |p| plan_ids_in_broker_catalog.include?(p.broker_provided_id) }
      plans_in_db_not_in_catalog.each do |plan_to_deactivate|
        if plan_to_deactivate.service_instances_dataset.count < 1
          plan_to_deactivate.destroy
          @services_event_repository.record_service_plan_event(:delete, plan_to_deactivate)
        end
      end
    end

    def delete_services(catalog)
      services_in_db_not_in_catalog = catalog.service_broker.services_dataset.where(Sequel.lit('unique_id NOT in ?', catalog.services.map(&:broker_provided_id)))
      services_in_db_not_in_catalog.each do |service|
        if service.service_plans_dataset.count < 1
          service.destroy
          @services_event_repository.record_service_event(:delete, service)
        end
      end
    end

    class DeactivatedPlansWarning
      WARNING = <<~END_OF_STRING.squish.freeze
        Warning: Service plans are missing from the broker's catalog (%<broker_url>s/v2/catalog) but can not be removed from
        Cloud Foundry while instances exist. The plans have been deactivated to prevent users from attempting to provision new
        instances of these plans. The broker should continue to support bind, unbind, and delete for existing instances; if
        these operations fail contact your broker provider.
      END_OF_STRING

      def initialize
        @nested_warnings = {}
      end

      def message
        return nil if @nested_warnings.empty?

        sprintf(WARNING, broker_url: @broker_url) + format_message
      end

      def add(plan)
        @nested_warnings[plan.service.label] ||= []
        @broker_url ||= plan.service_broker.broker_url
        @nested_warnings[plan.service.label] << plan.name
      end

      def format_message
        warning_msg = "\n"

        @nested_warnings.sort.each do |pair|
          service, plans = pair
          warning_msg += "\n"
          warning_msg += "Service Offering: #{service}\n"
          warning_msg += "Plans deactivated: #{plans.sort.join(', ')}\n"
        end

        warning_msg.chop

        warning_msg
      end
    end
  end
end
