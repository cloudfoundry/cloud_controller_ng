module VCAP::CloudController
  class OrganizationInstanceUsageCalculator
    def self.get_instance_usage(org)
      instance_usage = 0

      spaces = Space.where(organization: org).eager(apps: proc { |ds| ds.where(state: 'STARTED') }).all

      spaces.each do |space|
        space.apps.each do |app|
          instance_usage += app.instances
        end
      end

      instance_usage
    end
  end
end
