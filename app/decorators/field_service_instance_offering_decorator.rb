module VCAP::CloudController
  class FieldServiceInstanceOfferingDecorator
    def self.allowed
      Set['name', 'guid']
    end

    def self.match?(fields)
      fields.is_a?(Hash) && fields[:'service_plan.service_offering']&.to_set&.intersect?(self.allowed)
    end

    def initialize(fields)
      @fields = fields[:'service_plan.service_offering'].to_set.intersection(self.class.allowed)
    end

    def decorate(hash, service_instances)
      hash[:included] ||= {}
      plans = service_instances.map(&:service_plan).uniq
      offerings = plans.map(&:service).uniq

      hash[:included][:service_offerings] = offerings.sort_by(&:created_at).map do |offering|
        offering_view = {}
        offering_view[:name] = offering.name if @fields.include?('name')
        offering_view[:guid] = offering.guid if @fields.include?('guid')
        offering_view
      end

      hash
    end
  end
end
