Sequel.migration do
  change do
    create_table(:task_annotations) do
      VCAP::Migration.common(self)
      VCAP::Migration.annotations_common(self, :task_annotations, :tasks)
    end
  end
end
