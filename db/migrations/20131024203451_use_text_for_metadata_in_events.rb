Sequel.migration do
  up do
    # Migrations send missing methods to an instance of Sequel::Database.
    # All the old data in the events table is considered invalid, so chop it off.\
    self[:events].truncate

    alter_table(:events) do
      if Sequel::Model.db.database_type == :mssql
        drop_constraint(Sequel::Model.db.default_constraint_name('EVENTS', 'METADATA'))
      end

      set_column_allow_null :metadata
      set_column_default :metadata, nil
      if Sequel::Model.db.database_type == :mssql
        set_column_type :metadata, String, size: :max
      else
        set_column_type :metadata, String, text: 'true'
      end
    end
  end

  down do
    # The current data in events is invalid with regard to the old schema, so truncate here too.
    self[:events].truncate

    alter_table(:events) do
      if Sequel::Model.db.database_type == :mssql
        drop_constraint(Sequel::Model.db.default_constraint_name('EVENTS', 'METADATA'))
      end

      set_column_type :metadata, String
      set_column_default :metadata, '{}'
      set_column_not_null :metadata
    end
  end
end
