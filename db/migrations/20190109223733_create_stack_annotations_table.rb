Sequel.migration do
  change do
    create_table(:stack_annotations) do
      VCAP::Migration.common(self)
      VCAP::Migration.annotations_common(self, :stack_annotations, :stacks)
    end
  end
end
