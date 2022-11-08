module VCAP::CloudController
  class FieldServiceInstancePlanDecorator
    def self.allowed
      Set['guid', 'name', 'relationships.service_offering']
    end

    def self.match?(fields)
      fields.is_a?(Hash) && fields[:service_plan]&.to_set&.intersect?(self.allowed)
    end

    def initialize(fields)
      @fields = fields[:service_plan].to_set.intersection(self.class.allowed)
    end

    def decorate(hash, service_instances)
      managed_service_instances = service_instances.select(&:managed_instance?)
      return hash if managed_service_instances.empty?

      hash[:included] ||= {}
      plans = managed_service_instances.map(&:service_plan).uniq

      hash[:included][:service_plans] = plans.sort_by(&:created_at).map do |plan|
        plan_view = {}
        plan_view[:guid] = plan.guid if @fields.include?('guid')
        plan_view[:name] = plan.name if @fields.include?('name')
        if @fields.include?('relationships.service_offering')
          plan_view[:relationships] = {
            service_offering: {
              data: {
                guid: plan.service_guid
              }
            }
          }
        end

        plan_view
      end

      hash
    end
  end
end
