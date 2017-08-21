module VCAP::Services
  class ServiceClientProvider
    def self.provide(opts={})
      return provide_client_for_broker(opts[:broker]) if opts[:broker]
      return provide_client_for_binding(opts[:binding]) if opts[:binding]
      provide_client_for_instance(opts[:instance]) if opts[:instance]
    end

    class << self
      private

      def provide_client_for_binding(service_binding)
        provide_client_for_instance(service_binding.service_instance)
      end

      def provide_client_for_instance(service_instance)
        if service_instance.is_a? VCAP::CloudController::UserProvidedServiceInstance
          VCAP::Services::ServiceBrokers::UserProvided::Client.new
        else
          provide_client_for_broker(service_instance.service_broker)
        end
      end

      def provide_client_for_broker(service_broker)
        client_attrs = {
          url: service_broker.broker_url,
          auth_username: service_broker.auth_username,
          auth_password: service_broker.auth_password
        }
        VCAP::Services::ServiceBrokers::V2::Client.new(client_attrs)
      end
    end
  end
end
