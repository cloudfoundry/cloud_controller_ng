Sequel.migration do
  up do
    uuid_function = if self.class.name.match?(/mysql/i)
                      Sequel.function(:UUID)
                    elsif self.class.name.match?(/postgres/i)
                      Sequel.function(:get_uuid)
                    end

    self[:spaces_auditors].
      update(role_guid: uuid_function, updated_at: Sequel::CURRENT_TIMESTAMP)

    self[:spaces_managers].
      update(role_guid: uuid_function, updated_at: Sequel::CURRENT_TIMESTAMP)

    self[:spaces_developers].
      update(role_guid: uuid_function, updated_at: Sequel::CURRENT_TIMESTAMP)

    self[:organizations_users].
      update(role_guid: uuid_function, updated_at: Sequel::CURRENT_TIMESTAMP)

    self[:organizations_managers].
      update(role_guid: uuid_function, updated_at: Sequel::CURRENT_TIMESTAMP)

    self[:organizations_auditors].
      update(role_guid: uuid_function, updated_at: Sequel::CURRENT_TIMESTAMP)

    self[:organizations_billing_managers].
      update(role_guid: uuid_function, updated_at: Sequel::CURRENT_TIMESTAMP)
  end

  down do
    # Not reversible. Rollback the previous migration to drop the columns filled here.
  end
end
