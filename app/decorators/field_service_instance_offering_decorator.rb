module VCAP::CloudController
  class FieldServiceInstanceOfferingDecorator
    def self.allowed
      Set['name', 'guid', 'relationships.service_broker']
    end

    def self.match?(fields)
      fields.is_a?(Hash) && fields[:'service_plan.service_offering']&.to_set&.intersect?(self.allowed)
    end

    def initialize(fields)
      @fields = fields[:'service_plan.service_offering'].to_set.intersection(self.class.allowed)
    end

    def decorate(hash, service_instances)
      managed_service_instances = service_instances.select(&:managed_instance?)
      return hash if managed_service_instances.empty?

      hash[:included] ||= {}
      plans = managed_service_instances.map(&:service_plan).uniq
      offerings = plans.map(&:service).uniq

      hash[:included][:service_offerings] = offerings.sort_by(&:created_at).map do |offering|
        offering_view = {}
        offering_view[:name] = offering.name if @fields.include?('name')
        offering_view[:guid] = offering.guid if @fields.include?('guid')
        if @fields.include?('relationships.service_broker')
          offering_view[:relationships] = {
            service_broker: {
              data: {
                name: offering.service_broker.name,
                guid: offering.service_broker.guid
              }
            }
          }
        end

        offering_view
      end

      hash
    end
  end
end
