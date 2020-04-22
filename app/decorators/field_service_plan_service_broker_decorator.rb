module VCAP::CloudController
  class FieldServicePlanServiceBrokerDecorator
    def self.allowed
      Set['name', 'guid']
    end

    def self.match?(fields)
      fields.is_a?(Hash) && fields[:'service_offering.service_broker']&.to_set&.intersect?(self.allowed)
    end

    def initialize(fields)
      @fields = fields[:'service_offering.service_broker'].to_set.intersection(self.class.allowed)
    end

    def decorate(hash, service_plans)
      hash[:included] ||= {}
      service_offerings = service_plans.map(&:service).uniq
      service_brokers = service_offerings.map(&:service_broker).uniq
      hash[:included][:service_brokers] = service_brokers.sort_by(&:created_at).map do |broker|
        broker_view = {}
        broker_view[:name] = broker.name if @fields.include?('name')
        broker_view[:guid] = broker.guid if @fields.include?('guid')
        broker_view
      end

      hash
    end
  end
end
