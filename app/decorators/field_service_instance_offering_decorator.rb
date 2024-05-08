module VCAP::CloudController
  class FieldServiceInstanceOfferingDecorator
    def self.allowed
      Set.new(%w[name guid description documentation_url tags relationships.service_broker])
    end

    def self.match?(fields)
      fields.is_a?(Hash) && fields[:'service_plan.service_offering']&.to_set&.intersect?(allowed)
    end

    def initialize(fields)
      @fields = fields[:'service_plan.service_offering'].to_set.intersection(self.class.allowed)
    end

    def decorate(hash, service_instances)
      managed_service_instances = service_instances.select(&:managed_instance?)
      return hash if managed_service_instances.empty?

      offerings = Service.
                  join(:service_plans, service_id: :services__id).
                  join(:service_instances, service_plan_id: :service_plans__id).
                  where(service_instances__id: managed_service_instances.map(&:id)).
                  distinct.
                  order_by(:services__created_at).
                  select(:services__label, :services__guid, :services__description, :services__tags, :services__extra, :services__service_broker_id, :services__created_at).
                  all

      hash[:included] ||= {}
      hash[:included][:service_offerings] = offerings.map do |offering|
        offering_view = {}
        offering_view[:name] = offering.name if @fields.include?('name')
        offering_view[:guid] = offering.guid if @fields.include?('guid')
        offering_view[:description] = offering.description if @fields.include?('description')
        offering_view[:tags] = offering.tags if @fields.include?('tags')
        offering_view[:documentation_url] = extract_documentation_url(offering.extra) if @fields.include?('documentation_url')
        if @fields.include?('relationships.service_broker')
          offering_view[:relationships] = {
            service_broker: {
              data: {
                guid: offering.service_broker.guid
              }
            }
          }
        end

        offering_view
      end

      hash
    end

    private

    def extract_documentation_url(extra)
      metadata = Oj.load(extra)
      metadata['documentationUrl']
    rescue StandardError
      nil
    end
  end
end
