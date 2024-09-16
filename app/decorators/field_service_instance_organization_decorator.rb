module VCAP::CloudController
  class FieldServiceInstanceOrganizationDecorator
    def self.allowed
      Set['name', 'guid']
    end

    def self.match?(fields)
      fields.is_a?(Hash) && fields[:'space.organization']&.to_set&.intersect?(allowed)
    end

    def initialize(fields)
      @fields = fields[:'space.organization'].to_set.intersection(self.class.allowed)
    end

    def decorate(hash, resources)
      hash[:included] ||= {}

      spaces = resources.map { |r| r.try(:space) || r }.uniq
      orgs = spaces.map(&:organization).uniq
      all_orgs_readable, readable_org_guids = permissions(orgs)

      hash[:included][:organizations] = orgs.sort_by { |o| [o.created_at, o.guid] }.map do |org|
        org_view = {}
        org_view[:guid] = org.guid if @fields.include?('guid')
        org_view[:name] = org.name if @fields.include?('name') && (all_orgs_readable || readable_org_guids.include?(org.guid))
        org_view
      end

      hash
    end

    private

    # This method is used to check if the user has permissions to read the organizations and display their names.
    def permissions(orgs)
      permission_queryer = Permissions.new(SecurityContext.current_user)
      return [true, nil] if permission_queryer.can_read_globally?

      [false, Organization.where(guid: orgs.map(&:guid)).where(guid: permission_queryer.readable_org_guids_query).select_map(:guid)]
    end
  end
end
