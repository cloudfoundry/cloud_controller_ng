Sequel.migration do
  up do
    self[:organizations_users].where(role_guid: nil).update(
      role_guid: VCAP::Migration.uuid_function(self),
      updated_at: Sequel::CURRENT_TIMESTAMP
    )
  end

  down do
    # Not reversible. Rollback earlier migration to drop the columns filled here.
  end
end
