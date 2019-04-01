Sequel.migration do
  change do
    create_table(:stack_labels) do
      VCAP::Migration.common(self)
      VCAP::Migration.labels_common(self, :stack_labels, :stacks)
    end
  end
end
