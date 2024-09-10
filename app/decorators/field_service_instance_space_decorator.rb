module VCAP::CloudController
  class FieldServiceInstanceSpaceDecorator
    def self.match?(fields)
      fields.is_a?(Hash) && fields[:space]&.to_set&.intersect?(allowed)
    end

    def self.allowed
      Set['guid', 'name', 'relationships.organization']
    end

    def initialize(fields)
      @fields = fields[:space].to_set.intersection(self.class.allowed)
    end

    def decorate(hash, resources)
      hash[:included] ||= {}

      spaces = resources.map { |r| r.try(:space) || r }.uniq
      all_spaces_readable, readable_space_guids = permissions(spaces)

      hash[:included][:spaces] = spaces.sort_by { |s| [s.created_at, s.guid] }.map do |space|
        temp = {}
        temp[:guid] = space.guid if @fields.include?('guid')
        temp[:name] = space.name if @fields.include?('name') && (all_spaces_readable || readable_space_guids.include?(space.guid))
        if @fields.include?('relationships.organization')
          temp[:relationships] =
            {
              organization: {
                data: {
                  guid: space.organization.guid
                }
              }
            }
        end
        temp
      end

      hash
    end

    private

    # This method is used to check if the user has permissions to read the spaces and display their names.
    def permissions(spaces)
      permission_queryer = Permissions.new(SecurityContext.current_user)
      return [true, nil] if permission_queryer.can_read_globally?

      [false, Space.where(guid: spaces.map(&:guid)).where(guid: permission_queryer.readable_space_guids_query).select_map(:guid)]
    end
  end
end
