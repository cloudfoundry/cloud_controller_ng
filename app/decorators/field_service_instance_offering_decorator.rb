module VCAP::CloudController
  class FieldServiceInstanceOfferingDecorator
    def self.allowed
      Set.new(%w(name guid description documentation_url tags relationships.service_broker))
    end

    def self.match?(fields)
      fields.is_a?(Hash) && fields[:'service_plan.service_offering']&.to_set&.intersect?(self.allowed)
    end

    def initialize(fields)
      @fields = fields[:'service_plan.service_offering'].to_set.intersection(self.class.allowed)
    end

    # rubocop:todo Metrics/CyclomaticComplexity
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
    # rubocop:enable Metrics/CyclomaticComplexity

    private

    def extract_documentation_url(extra)
      metadata = JSON.parse(extra)
      metadata['documentationUrl']
    rescue JSON::ParserError
      nil
    end
  end
end
