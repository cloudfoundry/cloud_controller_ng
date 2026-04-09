module VCAP::CloudController
  class IncludeAccessRuleSelectorResourceDecorator
    # Handles `?include=selector_resource` for GET /v3/access_rules
    # Stale/missing resources (selector GUIDs that no longer exist) are silently absent.

    SELECTOR_REGEX = /\Acf:(app|space|org):([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})\z/

    def self.match?(include_params)
      include_params&.include?('selector_resource')
    end

    def self.decorate(hash, access_rules)
      included = []

      access_rules.each do |rule|
        match = SELECTOR_REGEX.match(rule.selector)
        next unless match

        resource_type = match[1]
        resource_guid = match[2]

        resource = case resource_type
                   when 'app'
                     VCAP::CloudController::AppModel.find(guid: resource_guid)
                   when 'space'
                     VCAP::CloudController::Space.find(guid: resource_guid)
                   when 'org'
                     VCAP::CloudController::Organization.find(guid: resource_guid)
                   end

        next if resource.nil?

        included << { type: resource_type, guid: resource.guid }
      end

      hash[:included] = { selector_resources: included }
      hash
    end
  end
end
