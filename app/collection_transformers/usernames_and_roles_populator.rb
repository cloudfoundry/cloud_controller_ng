module VCAP::CloudController
  class UsernamesAndRolesPopulator
    attr_reader :uaa_client

    def initialize(uaa_client)
      @uaa_client = uaa_client
    end

    def transform(users, opts={})
      user_ids = users.collect(&:guid)
      username_mapping = uaa_client.usernames_for_ids(user_ids)
      organization_id = opts[:organization_id]
      space_id = opts[:space_id]
      organization_roles = map_organization_roles(users, organization_id) unless organization_id.nil?
      space_roles = map_space_roles(users, space_id) unless space_id.nil?

      users.each do |user|
        user.username = username_mapping[user.guid]
        user.organization_roles = organization_roles[user.guid] unless organization_roles.nil?
        user.space_roles = space_roles[user.guid] unless space_roles.nil?
      end
    end

    private

    def map_organization_roles(users, org_id)
      users.each_with_object({}) do |u, mapping|
        organization_roles = build_organization_roles(u, org_id)
        mapping[u.guid] = organization_roles
      end
    end

    def map_space_roles(users, space_id)
      users.each_with_object({}) do |u, mapping|
        space_roles = build_space_roles(u, space_id)
        mapping[u.guid] = space_roles
      end
    end

    def build_organization_roles(user, org_id)
      roles = []
      roles << 'org_user' if user.organizations.collect(&:id).include?(org_id)
      roles << 'org_manager' if user.managed_organizations.collect(&:id).include?(org_id)
      roles << 'org_auditor' if user.audited_organizations.collect(&:id).include?(org_id)
      roles << 'billing_manager' if user.billing_managed_organizations.collect(&:id).include?(org_id)
      roles
    end

    def build_space_roles(user, space_id)
      roles = []
      roles << 'space_developer' if user.spaces.collect(&:id).include?(space_id)
      roles << 'space_manager' if user.managed_spaces.collect(&:id).include?(space_id)
      roles << 'space_auditor' if user.audited_spaces.collect(&:id).include?(space_id)
      roles
    end
  end
end
