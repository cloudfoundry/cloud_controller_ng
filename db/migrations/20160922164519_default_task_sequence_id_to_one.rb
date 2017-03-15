Sequel.migration do
  change do
    alter_table(:apps) do
      if Sequel::Model.db.database_type == :mssql
        drop_constraint(Sequel::Model.db.default_constraint_name('APPS', 'MAX_TASK_SEQUENCE_ID'))
      end
      set_column_default(:max_task_sequence_id, 1)
    end
  end
end
