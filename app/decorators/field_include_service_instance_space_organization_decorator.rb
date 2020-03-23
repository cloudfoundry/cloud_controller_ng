module VCAP::CloudController
  class FieldIncludeServiceInstanceSpaceOrganizationDecorator
    class << self
      def match?(fields)
        fields.is_a?(Hash) && fields[:'space.organization'] == ['name']
      end

      def decorate(hash, service_instances)
        hash[:included] ||= {}
        spaces = service_instances.map(&:space).uniq
        orgs = spaces.map(&:organization).uniq

        hash[:included][:spaces] = spaces.sort_by(&:created_at).map do |space|
          {
            name: space.name,
            guid: space.guid,
            relationships: {
              organization: {
                data: {
                  guid: space.organization.guid
                }
              }
            }
          }
        end

        hash[:included][:organizations] = orgs.sort_by(&:created_at).map do |org|
          {
            name: org.name,
            guid: org.guid
          }
        end

        hash
      end
    end
  end
end
