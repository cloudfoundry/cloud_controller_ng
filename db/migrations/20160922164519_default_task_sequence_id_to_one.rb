Sequel.migration do
  change do
    alter_table(:apps) do
      set_column_default(:max_task_sequence_id, 1)
    end
  end
end
