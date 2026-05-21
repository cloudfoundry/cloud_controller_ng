module VCAP::CloudController
  class IncludeRoutePolicySourceDecorator
    # Handles `?include=source` for GET /v3/route_policies
    # Stale/missing resources (source GUIDs that no longer exist) are silently absent.

    SOURCE_REGEX = /\Acf:(app|space|org):([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})\z/

    def self.match?(include_params)
      return false unless include_params

      include_params.include?('source')
    end

    def self.decorate(hash, route_policies)
      hash[:included] ||= {}

      # Collect all GUIDs by type
      app_guids = []
      space_guids = []
      org_guids = []

      route_policies.each do |policy|
        match = SOURCE_REGEX.match(policy.source)
        next unless match

        resource_type = match[1]
        resource_guid = match[2]

        case resource_type
        when 'app'
          app_guids << resource_guid
        when 'space'
          space_guids << resource_guid
        when 'org'
          org_guids << resource_guid
        end
      end

      # Fetch and present resources
      hash[:included][:apps] = fetch_and_present_apps(app_guids.uniq)
      hash[:included][:spaces] = fetch_and_present_spaces(space_guids.uniq)
      hash[:included][:organizations] = fetch_and_present_organizations(org_guids.uniq)

      hash
    end

    private_class_method def self.fetch_and_present_apps(guids)
      return [] if guids.empty?

      apps = AppModel.where(guid: guids).
             order(:created_at, :guid).
             eager(Presenters::V3::AppPresenter.associated_resources).all
      apps.map { |app| Presenters::V3::AppPresenter.new(app).to_hash }
    end

    private_class_method def self.fetch_and_present_spaces(guids)
      return [] if guids.empty?

      spaces = Space.where(guid: guids).
               order(:created_at, :guid).
               eager(Presenters::V3::SpacePresenter.associated_resources).all
      spaces.map { |space| Presenters::V3::SpacePresenter.new(space).to_hash }
    end

    private_class_method def self.fetch_and_present_organizations(guids)
      return [] if guids.empty?

      orgs = Organization.where(guid: guids).
             order(:created_at, :guid).
             eager(Presenters::V3::OrganizationPresenter.associated_resources).all
      orgs.map { |org| Presenters::V3::OrganizationPresenter.new(org).to_hash }
    end
  end
end
