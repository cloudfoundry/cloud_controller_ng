module VCAP::CloudController
  class UsernamesAndRolesPopulator
    attr_reader :uaa_client

    def initialize(uaa_client)
      @uaa_client = uaa_client
    end

    def transform(users, opts={})
      user_guids = users.map(&:guid)
      username_mapping = uaa_client.usernames_for_ids(user_guids)
      organization_id = opts[:organization_id]
      space_id = opts[:space_id]
      organization_roles = map_organization_roles(user_guids, organization_id) unless organization_id.nil?
      space_roles = map_space_roles(user_guids, space_id) unless space_id.nil?

      users.each do |user|
        user.username = username_mapping[user.guid]
        user.organization_roles = organization_roles[user.guid] unless organization_roles.nil?
        user.space_roles = space_roles[user.guid] unless space_roles.nil?
      end
    end

    private

    def map_organization_roles(user_guids, org_id)
      org = Organization.find(id: org_id)
      org_user_guids = subset_of_guids(org.users_dataset, user_guids)
      manager_guids = subset_of_guids(org.managers_dataset, user_guids)
      auditor_guids = subset_of_guids(org.auditors_dataset, user_guids)
      billing_manager_guids = subset_of_guids(org.billing_managers_dataset, user_guids)
      user_guids.each_with_object({}) do |u, mapping|
        organization_roles = []
        organization_roles << 'org_user' if org_user_guids.include?(u)
        organization_roles << 'org_manager' if manager_guids.include?(u)
        organization_roles << 'org_auditor' if auditor_guids.include?(u)
        organization_roles << 'billing_manager' if billing_manager_guids.include?(u)
        mapping[u] = organization_roles
      end
    end

    def map_space_roles(user_guids, space_id)
      space = Space.find(id: space_id)
      developer_guids = subset_of_guids(space.developers_dataset, user_guids)
      manager_guids = subset_of_guids(space.managers_dataset, user_guids)
      auditor_guids = subset_of_guids(space.auditors_dataset, user_guids)
      user_guids.each_with_object({}) do |u, mapping|
        space_roles = []
        space_roles << 'space_developer' if developer_guids.include?(u)
        space_roles << 'space_manager' if manager_guids.include?(u)
        space_roles << 'space_auditor' if auditor_guids.include?(u)
        mapping[u] = space_roles
      end
    end

    def subset_of_guids(role_dataset, user_guids)
      role_dataset.where(guid: user_guids).select(:guid).map(&:guid)
    end
  end
end
