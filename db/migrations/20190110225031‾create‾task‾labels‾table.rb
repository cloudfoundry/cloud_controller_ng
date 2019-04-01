Sequel.migration do
  change do
    create_table(:task_labels) do
      VCAP::Migration.common(self)
      VCAP::Migration.labels_common(self, :task_labels, :tasks)
    end
  end
end
