module VCAP::CloudController
  class FieldServiceInstanceOrganizationDecorator
    def self.allowed
      Set['name', 'guid']
    end

    def self.match?(fields)
      fields.is_a?(Hash) && fields[:'space.organization']&.to_set&.intersect?(self.allowed)
    end

    def initialize(fields)
      @fields = fields[:'space.organization'].to_set.intersection(self.class.allowed)
    end

    def decorate(hash, resources)
      hash[:included] ||= {}
      spaces = resources.map { |r| r.try(:space) || r }.uniq
      orgs = spaces.map(&:organization).uniq

      hash[:included][:organizations] = orgs.sort_by(&:created_at).map do |org|
        org_view = {}
        org_view[:name] = org.name if @fields.include?('name')
        org_view[:guid] = org.guid if @fields.include?('guid')
        org_view
      end

      hash
    end
  end
end
