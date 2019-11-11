Sequel.migration do
  change do
    not_specified = -1

    create_view :roles,
      self[:organizations_users].select(
        Sequel.as('organization_user', :type),
        Sequel.as(:role_guid, :guid),
        :user_id,
        :organization_id,
        Sequel.as(not_specified, :space_id),
        :created_at,
        :updated_at
      ).union(
        self[:organizations_managers].select(
          Sequel.as('organization_manager', :type),
          Sequel.as(:role_guid, :guid),
          :user_id,
          :organization_id,
          Sequel.as(not_specified, :space_id),
          :created_at,
          :updated_at)
      ).union(
        self[:organizations_billing_managers].select(
          Sequel.as('organization_billing_manager', :type),
          Sequel.as(:role_guid, :guid),
          :user_id,
          :organization_id,
          Sequel.as(not_specified, :space_id),
          :created_at,
          :updated_at)
      ).union(
        self[:organizations_auditors].select(
          Sequel.as('organization_auditor', :type),
          Sequel.as(:role_guid, :guid),
          :user_id,
          :organization_id,
          Sequel.as(not_specified, :space_id),
          :created_at,
          :updated_at)
      ).union(
        self[:spaces_developers].select(
          Sequel.as('space_developer', :type),
          Sequel.as(:role_guid, :guid),
          :user_id,
          Sequel.as(not_specified, :organization_id),
          :space_id,
          :created_at,
          :updated_at)
      ).union(
        self[:spaces_auditors].select(
          Sequel.as('space_auditor', :type),
          Sequel.as(:role_guid, :guid),
          :user_id,
          Sequel.as(not_specified, :organization_id),
          :space_id,
          :created_at,
          :updated_at)
      ).union(
        self[:spaces_managers].select(
          Sequel.as('space_manager', :type),
          Sequel.as(:role_guid, :guid),
          :user_id,
          Sequel.as(not_specified, :organization_id),
          :space_id,
          :created_at,
          :updated_at))
  end
end
