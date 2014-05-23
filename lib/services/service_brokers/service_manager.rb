module VCAP::Services::ServiceBrokers
  class ServiceManager
    attr_reader :catalog, :warnings

    def initialize(catalog)
      @catalog = catalog
      @warnings = []
    end

    def sync_services_and_plans
      update_or_create_services
      deactivate_services
      update_or_create_plans
      deactivate_plans
      delete_plans
      delete_services
    end

    def has_warnings?
      warnings.length > 0
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
      deactivated_plans_warning  = DeactivatedPlansWarning.new

      plans_in_db_not_in_catalog.each do |plan_to_deactivate|
        plan_to_deactivate.active = false
        plan_to_deactivate.save

        deactivated_plans_warning.add(plan_to_deactivate)
      end

      @warnings << deactivated_plans_warning.message if deactivated_plans_warning.message
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
