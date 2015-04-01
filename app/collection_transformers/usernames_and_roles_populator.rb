module VCAP::CloudController
  class UsernamesAndRolesPopulator
    attr_reader :uaa_client

    def initialize(uaa_client)
      @uaa_client = uaa_client
    end

    def transform(users, opts)
      user_ids = users.collect(&:guid)
      username_mapping = uaa_client.usernames_for_ids(user_ids)
      user_to_roles_map = map_organization_roles(users, opts[:organization_id])

      users.each do |user|
        user.username = username_mapping[user.guid]
        user.organization_roles = user_to_roles_map[user.guid]
      end
    end

    private

    def map_organization_roles(users, org_id)
      users.each_with_object({}) do |u, mapping|
        organization_roles = build_organization_roles(u, org_id)
        mapping[u.guid] = organization_roles
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
  end
end
