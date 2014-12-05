module VCAP::Services::ServiceBrokers
  class ServiceBrokerRemover
    attr_reader :broker, :client_manager

    def initialize(broker, services_event_repository)
      @broker = broker
      @services_event_repository = services_event_repository
      @client_manager = VCAP::Services::SSO::DashboardClientManager.new(broker, @services_event_repository)
    end

    def execute!
      cache = cache_services_and_plans(broker)

      client_manager.remove_clients_for_broker
      broker.destroy

      record_service_and_plan_deletion_events(cache)
    end

    private

    def cache_services_and_plans(broker)
      cached_services_and_plans = {}
      broker.services.each do |service|
        cached_services_and_plans[service.guid] = {
          service: service,
          plans: service.service_plans
        }
      end

      cached_services_and_plans
    end

    def record_service_and_plan_deletion_events(cached_services_and_plans)
      cached_services_and_plans.each do |_, hash|
        service = hash[:service]
        plans = hash[:plans]
        plans.each do |plan|
          @services_event_repository.record_service_plan_event(:delete, plan)
        end
        @services_event_repository.record_service_event(:delete, service)
      end
    end
  end
end
