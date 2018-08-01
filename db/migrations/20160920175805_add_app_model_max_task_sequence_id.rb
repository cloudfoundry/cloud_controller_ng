Sequel.migration do
  change do
    add_column :apps, :max_task_sequence_id, Integer, default: 0
  end
end
