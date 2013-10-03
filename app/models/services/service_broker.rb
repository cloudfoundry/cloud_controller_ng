module VCAP::CloudController
  class ServiceBroker < Sequel::Model
    one_to_many :services

    import_attributes :name, :broker_url, :auth_username, :auth_password
    export_attributes :name, :broker_url, :auth_username

    add_association_dependencies :services => :destroy

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
      catalog = Catalog.new(self)
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
      def initialize(broker)
        raise unless broker.valid?

        @broker = broker
      end

      def sync_services_and_plans
        catalog_services = @broker.client.catalog.fetch('services', [])
        catalog_services.each do |catalog_service|
          service_id = catalog_service.fetch('id')

          service = Service.update_or_create(
            service_broker: @broker,
            unique_id: service_id
          ) do |service|
            service.set(
              label: catalog_service.fetch('name'),
              description: catalog_service.fetch('description'),
              bindable: catalog_service.fetch('bindable')
            )
          end

          catalog_plans = catalog_service.fetch('plans', [])
          catalog_plans.each do |catalog_plan|
            plan_id = catalog_plan.fetch('id')

            ServicePlan.update_or_create(
              service: service,
              unique_id: plan_id
            ) do |plan|
              plan.set(
                name: catalog_plan.fetch('name'),
                description: catalog_plan.fetch('description'),
                free: true
              )
            end
          end
        end
      end
    end
  end
end
