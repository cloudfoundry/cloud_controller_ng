module VCAP::Services::ServiceBrokers
  class ServiceManager
    attr_reader :warnings

    def initialize(service_event_repository)
      @services_event_repository = service_event_repository
      @warnings = []
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
      warnings.length > 0
    end

    private

    def update_or_create_services(catalog)
      catalog.services.each do |catalog_service|
        cond = {
          service_broker: catalog_service.service_broker,
          unique_id:      catalog_service.broker_provided_id,
        }
        obj = find_or_new_model(VCAP::CloudController::Service, cond)

        obj.set(
          label:       catalog_service.name,
          description: catalog_service.description,
          bindable:    catalog_service.bindable,
          tags:        catalog_service.tags,
          extra:       catalog_service.metadata ? catalog_service.metadata.to_json : nil,
          active:      catalog_service.plans_present?,
          requires:    catalog_service.requires,
          plan_updateable: catalog_service.plan_updateable,
        )

        @services_event_repository.with_service_event(obj) do
          obj.save(changed: true)
        end
      end
    end

    def update_or_create_plans(catalog)
      catalog.plans.each do |catalog_plan|
        cond = {
          unique_id: catalog_plan.broker_provided_id,
          service: catalog_plan.catalog_service.cc_service,
        }
        plan = find_or_new_model(VCAP::CloudController::ServicePlan, cond)
        if plan.new?
          plan.public = false
        end

        plan.set({
          name:        catalog_plan.name,
          description: catalog_plan.description,
          free:        catalog_plan.free,
          active:      true,
          extra:       catalog_plan.metadata ? catalog_plan.metadata.to_json : nil
        })
        @services_event_repository.with_service_plan_event(plan) do
          plan.save(changed: true)
        end
      end
    end

    def find_or_new_model(model_class, cond)
      obj = model_class.first(cond)
      unless obj
        obj = model_class.new(cond)
      end
      obj
    end

    def deactivate_services(catalog)
      services_in_db_not_in_catalog = catalog.service_broker.services_dataset.where('unique_id NOT in ?', catalog.services.map(&:broker_provided_id))
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

        deactivated_plans_warning.add(plan_to_deactivate) if plan_to_deactivate.service_instances.count >= 1
      end

      @warnings << deactivated_plans_warning.message if deactivated_plans_warning.message
    end

    def delete_plans(catalog)
      plan_ids_in_broker_catalog = catalog.plans.map(&:broker_provided_id)
      plans_in_db_not_in_catalog = catalog.service_broker.service_plans.reject { |p| plan_ids_in_broker_catalog.include?(p.broker_provided_id) }
      plans_in_db_not_in_catalog.each do |plan_to_deactivate|
        if plan_to_deactivate.service_instances.count < 1
          plan_to_deactivate.destroy
          @services_event_repository.record_service_plan_event(:delete, plan_to_deactivate)
        end
      end
    end

    def delete_services(catalog)
      services_in_db_not_in_catalog = catalog.service_broker.services_dataset.where('unique_id NOT in ?', catalog.services.map(&:broker_provided_id))
      services_in_db_not_in_catalog.each do |service|
        if service.service_plans.count < 1
          service.destroy
          @services_event_repository.record_service_event(:delete, service)
        end
      end
    end

    class DeactivatedPlansWarning
      # rubocop:disable LineLength
      WARNING = "Warning: Service plans are missing from the broker's catalog (%s/v2/catalog) but can not be removed from Cloud Foundry while instances exist. The plans have been deactivated to prevent users from attempting to provision new instances of these plans. The broker should continue to support bind, unbind, and delete for existing instances; if these operations fail contact your broker provider.\n".freeze
      # rubocop:enable LineLength
      INDENT = '  '.freeze

      def initialize
        @nested_warnings = {}
      end

      def message
        return nil if @nested_warnings.length == 0

        sprintf(WARNING, @broker_url) + format_message
      end

      def add(plan)
        @nested_warnings[plan.service.label] ||= []
        @broker_url ||= plan.service_broker.broker_url
        @nested_warnings[plan.service.label] << plan.name
      end

      def format_message
        warning_msg = ''

        @nested_warnings.sort.each do |pair|
          service, plans = pair
          warning_msg += "#{service}\n"
          plans.sort.each do |plan|
            warning_msg += "#{INDENT}#{plan}\n"
          end
        end

        warning_msg.chop

        warning_msg
      end
    end
  end
end
