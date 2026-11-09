Sequel.migration do
  up do
    alter_table(:service_accounts) { set_column_allow_null :space_guid }
  end

  down do
    raise Sequel::Error.new('Cannot restore space ownership while accounts have no original space') if from(:service_accounts).where(space_guid: nil).any?

    alter_table(:service_accounts) { set_column_not_null :space_guid }
  end
end
