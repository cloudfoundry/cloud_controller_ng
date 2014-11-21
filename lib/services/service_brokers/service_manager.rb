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

    def update_or_create(model, cond, &block)
      obj = model.first(cond)
      if obj
        obj.tap(&block).save(:changed => true)
      else
        instance = model.create(cond, &block)
        @services_event_repository.create_service_event('audit.service.create', instance, {
          entity: {
            broker_guid: instance.service_broker.guid,
            unique_id: instance.broker_provided_id,
            label: instance.label,
            description: instance.description,
            bindable: instance.bindable,
            tags: instance.tags,
            extra: instance.extra,
            active: instance.active,
            requires: instance.requires,
            plan_updateable: instance.plan_updateable,
          }
        })
        instance
      end
    end

    def update_or_create_services(catalog)
      catalog.services.each do |catalog_service|
        service_id = catalog_service.broker_provided_id

        update_or_create(VCAP::CloudController::Service,
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
            plan_updateable: catalog_service.plan_updateable,
          )
        end
      end
    end

    def deactivate_services(catalog)
      services_in_db_not_in_catalog = catalog.service_broker.services_dataset.where('unique_id NOT in ?', catalog.services.map(&:broker_provided_id))
      services_in_db_not_in_catalog.each do |service|
        service.update(active: false)
      end
    end

    def update_or_create_plans(catalog)
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

    def deactivate_plans(catalog)
      plan_ids_in_broker_catalog = catalog.plans.map(&:broker_provided_id)
      plans_in_db_not_in_catalog = catalog.service_broker.service_plans.reject { |p| plan_ids_in_broker_catalog.include?(p.broker_provided_id) }
      deactivated_plans_warning  = DeactivatedPlansWarning.new

      plans_in_db_not_in_catalog.each do |plan_to_deactivate|
        plan_to_deactivate.active = false
        plan_to_deactivate.save

        deactivated_plans_warning.add(plan_to_deactivate)
      end

      @warnings << deactivated_plans_warning.message if deactivated_plans_warning.message
    end

    def delete_plans(catalog)
      plan_ids_in_broker_catalog = catalog.plans.map(&:broker_provided_id)
      plans_in_db_not_in_catalog = catalog.service_broker.service_plans.reject { |p| plan_ids_in_broker_catalog.include?(p.broker_provided_id) }
      plans_in_db_not_in_catalog.each do |plan_to_deactivate|
        if plan_to_deactivate.service_instances.count < 1
          plan_to_deactivate.destroy
        end
      end
    end

    def delete_services(catalog)
      services_in_db_not_in_catalog = catalog.service_broker.services_dataset.where('unique_id NOT in ?', catalog.services.map(&:broker_provided_id))
      services_in_db_not_in_catalog.each do |service|
        if service.service_plans.count < 1
          service.destroy
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
        @broker_url                          ||= plan.service.service_broker.broker_url
        @nested_warnings[plan.service.label] << plan.name
      end

      def format_message
        warning_msg = ''

        @nested_warnings.each_pair do |service, plans|
          warning_msg += "#{service}\n"
          plans.each do |plan|
            warning_msg += "#{INDENT}#{plan}\n"
          end
        end

        warning_msg.chop

        warning_msg
      end
    end
  end
end
