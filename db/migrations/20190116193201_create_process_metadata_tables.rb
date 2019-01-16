Sequel.migration do
  change do
    create_table(:process_annotations) do
      VCAP::Migration.common(self)
      VCAP::Migration.annotations_common(self, :process_annotations, :processes)
    end

    create_table(:process_labels) do
      VCAP::Migration.common(self)
      VCAP::Migration.labels_common(self, :process_labels, :processes)
    end
  end
end
