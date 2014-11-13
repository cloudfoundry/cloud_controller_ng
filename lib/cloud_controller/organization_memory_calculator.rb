module VCAP::CloudController
  class OrganizationMemoryCalculator
    def self.get_memory_usage(org)
      memory_usage = 0

      spaces = Space.where(organization: org)

      spaces.eager(:apps).all do |space|
        space.apps.each do |app|
          memory_usage += app.memory * app.instances if app.started?
        end
      end

      memory_usage
    end
  end
end
