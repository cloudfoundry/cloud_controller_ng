Sequel.migration do
  change do
    alter_table(:tasks) do
      add_column :sequence_id, Integer
      add_unique_constraint [:app_guid, :sequence_id], name: :unique_task_app_guid_sequence_id
    end
  end
end
