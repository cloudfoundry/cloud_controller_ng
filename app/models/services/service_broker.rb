module VCAP::CloudController::Models
  class ServiceBroker < Sequel::Model
    one_to_many :services

    import_attributes :name, :broker_url, :token
    export_attributes :name, :broker_url

    add_association_dependencies :services => :destroy

    def validate
      validates_presence :name
      validates_presence :broker_url
      validates_presence :token
      validates_unique :name
      validates_unique :broker_url
    end

    def load_catalog
      catalog = Catalog.new(self)
      catalog.sync_services_and_plans
    end

    def token
      return unless super
      VCAP::CloudController::Encryptor.decrypt(super, salt)
    end

    def token=(value)
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

    class Catalog
      def initialize(broker)
        raise unless broker.broker_url.present? && broker.token.present?

        @broker = broker
      end

      def sync_services_and_plans
        catalog_services = raw_catalog.fetch('services', [])
        catalog_services.each do |catalog_service|
          service_id = catalog_service.fetch('id')

          service = Service.update_or_create(
            service_broker: @broker,
            unique_id: service_id
          ) do |service|
            service.set(
              label: catalog_service.fetch('name'),
              description: catalog_service.fetch('description'),
              bindable: false
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

      private

      def raw_catalog
        @raw_catalog ||= fetch_raw_catalog
      end

      def fetch_raw_catalog
        catalog_url = @broker.broker_url + '/v2/catalog'
        catalog_uri = URI(catalog_url)

        http = HTTPClient.new
        http.set_auth(catalog_url, 'cc', @broker.token)

        begin
          response = http.get(catalog_uri)
        rescue SocketError, HTTPClient::ConnectTimeoutError, Errno::ECONNREFUSED
          raise VCAP::Errors::ServiceBrokerApiUnreachable.new(@broker.broker_url)
        rescue HTTPClient::KeepAliveDisconnected, HTTPClient::ReceiveTimeoutError
          raise VCAP::Errors::ServiceBrokerApiTimeout.new(@broker.broker_url)
        end

        if response.code.to_i == HTTP::Status::UNAUTHORIZED
          raise VCAP::Errors::ServiceBrokerApiAuthenticationFailed.new(@broker.broker_url)
        elsif response.code.to_i != HTTP::Status::OK
          raise VCAP::Errors::ServiceBrokerResponseMalformed.new(@broker.broker_url)
        else
          begin
            raw_catalog = Yajl::Parser.parse(response.body)
          rescue Yajl::ParseError
          end

          unless raw_catalog.is_a?(Hash)
            raise VCAP::Errors::ServiceBrokerResponseMalformed.new(@broker.broker_url)
          end
        end

        raw_catalog
      end
    end
  end
end
