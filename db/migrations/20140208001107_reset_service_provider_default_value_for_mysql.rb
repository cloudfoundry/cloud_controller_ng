Sequel.migration do
  up do
    alter_table :services do
      if Sequel::Model.db.database_type == :mssql
        drop_constraint(Sequel::Model.db.default_constraint_name('SERVICES', 'PROVIDER'))
      end
      set_column_default :provider, ''
    end
  end

  down do
    # TODO: do we need to drop the default here?
    # no-op
  end
end
