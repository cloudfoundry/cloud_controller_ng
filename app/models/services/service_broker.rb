module VCAP::CloudController
  class ServiceBroker < Sequel::Model
  end

  require 'models/services/service_broker/v2/catalog_service'
  require 'models/services/service_broker/v2/catalog_plan'

  class ServiceBroker < Sequel::Model
    one_to_many :services

    import_attributes :name, :broker_url, :auth_username, :auth_password
    export_attributes :name, :broker_url, :auth_username

    add_association_dependencies :services => :destroy

    many_to_many :service_plans, :join_table => :services, :right_key => :id, :right_primary_key => :service_id

    def validate
      validates_presence :name
      validates_presence :broker_url
      validates_presence :auth_username
      validates_presence :auth_password
      validates_unique :name
      validates_unique :broker_url
      validates_url :broker_url
    end

    def load_catalog
      raise unless valid?
      catalog = Catalog.new(self, client.catalog)
      catalog.sync_services_and_plans
    end

    def auth_password
      return unless super
      VCAP::CloudController::Encryptor.decrypt(super, salt)
    end

    def auth_password=(value)
      generate_salt

      # Encryptor cannot encrypt an empty string
      if value.blank?
        super(nil)
      else
        super(VCAP::CloudController::Encryptor.encrypt(value, salt))
      end
    end

    def generate_salt
      self.salt ||= VCAP::CloudController::Encryptor.generate_salt
    end

    def client
      @client ||= ServiceBroker::V2::Client.new(url: broker_url, auth_username: auth_username, auth_password: auth_password)
    end

    private

    class Catalog
      attr_reader :service_broker, :services, :plans

      def initialize(service_broker, catalog_hash)
        @service_broker = service_broker
        @services       = []
        @plans          = []

        catalog_hash.fetch('services', []).each do |service_attrs|
          service = V2::CatalogService.new(service_broker, service_attrs)
          @services << service

          service_plans = service_attrs.fetch('plans', [])
          if service_plans.empty?
            @service_broker.errors.add(:services, 'each service must have at least one plan')
            raise Errors::ServiceBrokerInvalid.new("each service must have at least one plan")
          end

          service_plans.each do |plan_attrs|
            plan = V2::CatalogPlan.new(service, plan_attrs)
            @plans << plan
          end
        end
      end

      def sync_services_and_plans
        update_or_create_services
        deactive_services
        update_or_create_plans
        deactivate_plans
        delete_plans
        delete_services
      end

      private

      def update_or_create_services
        services.each do |catalog_service|
          service_id = catalog_service.broker_provided_id

          Service.update_or_create(
            service_broker: service_broker,
            unique_id:      service_id
          ) do |service|
            service.set(
              label:       catalog_service.name,
              description: catalog_service.description,
              bindable:    catalog_service.bindable,
              tags:        catalog_service.tags,
              extra:       catalog_service.metadata ? catalog_service.metadata.to_json : nil,
              active:      catalog_service.plans_present?
            )
          end
        end
      end

      def deactive_services
        services_in_db_not_in_catalog = Service.where('unique_id NOT in ?', services.map(&:broker_provided_id))
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
            ServicePlan.create(
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
        services_in_db_not_in_catalog = Service.where('unique_id NOT in ?', services.map(&:broker_provided_id))
        services_in_db_not_in_catalog.each do |service|
          if service.service_plans.count < 1
            service.destroy
          end
        end
      end
    end
  end
end
