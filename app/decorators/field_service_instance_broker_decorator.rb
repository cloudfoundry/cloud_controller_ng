module VCAP::CloudController
  class FieldServiceInstanceBrokerDecorator
    def self.allowed
      Set['name', 'guid']
    end

    def self.match?(fields)
      fields.is_a?(Hash) && fields[:'service_plan.service_offering.service_broker']&.to_set&.intersect?(allowed)
    end

    def initialize(fields)
      @fields = fields[:'service_plan.service_offering.service_broker'].to_set.intersection(self.class.allowed)
    end

    def decorate(hash, service_instances)
      managed_service_instances = service_instances.select(&:managed_instance?)
      return hash if managed_service_instances.empty?

      brokers = ServiceBroker.
                join(:services, service_broker_id: :service_brokers__id).
                join(:service_plans, service_id: :services__id).
                join(:service_instances, service_plan_id: :service_plans__id).
                where(service_instances__id: managed_service_instances.map(&:id)).
                distinct.
                order_by(:service_brokers__created_at).
                select(:service_brokers__name, :service_brokers__guid).
                all

      hash[:included] ||= {}
      hash[:included][:service_brokers] = brokers.map do |broker|
        broker_view = {}
        broker_view[:name] = broker.name if @fields.include?('name')
        broker_view[:guid] = broker.guid if @fields.include?('guid')
        broker_view
      end

      hash
    end
  end
end
